// Galleria Clienti — app Mac che guida genera.py (--app) con una finestra sola.
// Build: ./app/build.sh  (compila e installa in /Applications)

import SwiftUI
import AppKit
import UniformTypeIdentifiers

let estensioniFoto: Set<String> = ["jpg", "jpeg", "png", "webp", "tiff", "tif", "bmp"]

// Percorso di genera.py scritto in Info.plist da build.sh
let generaPath = Bundle.main.object(forInfoDictionaryKey: "GeneraPath") as? String ?? ""

// Una riga JSON emessa da genera.py --app
struct Riga: Decodable, Sendable {
    let tipo: String
    var fase: String?, fatto: Int?, totale: Int?
    var link: String?, messaggio: String?, foto: Int?, testo: String?
}

enum Fase: Equatable {
    case compila
    case lavoro(testo: String, fatto: Int, totale: Int)
    case fatto(link: String, messaggio: String, foto: Int)
    case errore(String)
}

@MainActor
final class Modello: ObservableObject {
    @Published var cartella: URL?
    @Published var numFoto = 0
    @Published var evento = ""
    @Published var cliente = ""
    @Published var password = ""
    @Published var maxTesto = "0"
    var maxSel: Int { Int(maxTesto.filter(\.isNumber)) ?? 0 }
    @Published var fase: Fase = .compila

    var formatoOk: Bool { evento.range(of: #"^\d{6}_"#, options: .regularExpression) != nil }
    var pronto: Bool {
        cartella != nil && numFoto > 0 && !evento.trimmed.isEmpty && !cliente.trimmed.isEmpty && !password.trimmed.isEmpty
    }

    // Struttura dei lavori: AAMMGG_NomeEvento/{ARW, JPG, Edit}.
    // Si trascina la cartella JPG → evento = nome della cartella padre.
    // Se si trascina direttamente la cartella del lavoro, si usa la sua sottocartella JPG.
    func impostaCartella(_ url: URL) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
        let sotto = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? []).first { $0.lowercased() == "jpg" }
        let foto = sotto.map { url.appendingPathComponent($0) } ?? url
        cartella = foto
        let files = (try? fm.contentsOfDirectory(atPath: foto.path)) ?? []
        numFoto = files.filter { !$0.hasPrefix(".") && estensioniFoto.contains(($0 as NSString).pathExtension.lowercased()) }.count
        evento = foto.deletingLastPathComponent().lastPathComponent
        // La password proposta non sovrascrive mai quella gia' scritta
        if password.trimmed.isEmpty { password = Modello.suggerisciPassword(evento) }
        fase = .compila
    }

    // Stile delle password gia' usate: "Villa.Negri", "Zanzara12." — parola dell'evento + numero
    static func suggerisciPassword(_ evento: String) -> String {
        let parti = evento.split(separator: "_").dropFirst().map(String.init)
        let parola = (parti.last ?? "Foto").filter { $0.isLetter }
        return (parola.isEmpty ? "Foto" : parola) + "." + String(Int.random(in: 10...99))
    }

    func sceltaCartella() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.prompt = "Scegli"
        p.message = "Cartella JPG del lavoro (o la cartella del lavoro)"
        p.directoryURL = URL(fileURLWithPath: "/Volumes/HD_Foto/Foto/Finiti")
        if p.runModal() == .OK, let url = p.url { impostaCartella(url) }
    }

    func avvia() {
        guard let cartella, pronto else { return }
        fase = .lavoro(testo: "Avvio…", fatto: 0, totale: 0)
        let params: [String: Any] = [
            "cartella": cartella.path, "cliente": cliente.trimmed, "evento": evento.trimmed,
            "password": password.trimmed, "max": maxSel,
        ]
        let dati = try! JSONSerialization.data(withJSONObject: params)
        Task.detached {
            let esito = Modello.esegui(dati) { riga in
                Task { @MainActor in self.gestisci(riga) }
            }
            if let esito { await MainActor.run { self.fase = .errore(esito) } }
        }
    }

    private func gestisci(_ r: Riga) {
        switch r.tipo {
        case "progresso": fase = .lavoro(testo: r.fase ?? "", fatto: r.fatto ?? 0, totale: r.totale ?? 0)
        case "fine":      fase = .fatto(link: r.link ?? "", messaggio: r.messaggio ?? "", foto: r.foto ?? 0)
        case "errore":    fase = .errore(r.testo ?? "Errore sconosciuto")
        default: break
        }
    }

    // Lancia python3 genera.py --app; ritorna un messaggio d'errore solo se il processo fallisce senza spiegarlo
    nonisolated static func esegui(_ params: Data, riga: @escaping @Sendable (Riga) -> Void) -> String? {
        guard FileManager.default.fileExists(atPath: generaPath) else { return "genera.py non trovato in \(generaPath)" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [generaPath, "--app"]
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = errPipe
        do { try p.run() } catch { return "Impossibile avviare python3: \(error.localizedDescription)" }
        inPipe.fileHandleForWriting.write(params)
        try? inPipe.fileHandleForWriting.close()

        var buffer = Data(), ricevutoEsito = false
        while case let chunk = outPipe.fileHandleForReading.availableData, !chunk.isEmpty {
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                if let obj = try? JSONDecoder().decode(Riga.self, from: line) {
                    if obj.tipo == "fine" || obj.tipo == "errore" { ricevutoEsito = true }
                    riga(obj)
                }
            }
        }
        p.waitUntilExit()
        if p.terminationStatus != 0 && !ricevutoEsito {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return err.trimmed.isEmpty ? "genera.py è terminato con errore \(p.terminationStatus)" : err.trimmed
        }
        return nil
    }
}

extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

// ---------------- UI ----------------

struct Contenuto: View {
    @EnvironmentObject var m: Modello
    @State private var sopra = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch m.fase {
            case .compila: modulo
            case let .lavoro(testo, fatto, totale): lavoro(testo, fatto, totale)
            case let .fatto(link, messaggio, foto): fatto(link, messaggio, foto)
            case let .errore(testo): errore(testo)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onDrop(of: [.fileURL], isTargeted: $sopra) { prov in
            guard case .compila = m.fase, let p = prov.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in m.impostaCartella(url) } }
            }
            return true
        }
    }

    var modulo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: m.sceltaCartella) {
                VStack(spacing: 6) {
                    Image(systemName: m.cartella == nil ? "folder.badge.plus" : "photo.stack")
                        .font(.system(size: 28, weight: .light))
                    if let c = m.cartella {
                        Text(c.deletingLastPathComponent().lastPathComponent + " / " + c.lastPathComponent).font(.headline)
                        Text(m.numFoto == 0 ? "Nessuna foto in questa cartella" : "\(m.numFoto) foto")
                            .foregroundStyle(m.numFoto == 0 ? .red : .secondary)
                    } else {
                        Text("Trascina qui la cartella JPG del lavoro").font(.headline)
                        Text("oppure clicca per sceglierla").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 12).fill(sopra ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(sopra ? Color.accentColor : Color.primary.opacity(0.15),
                                                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))

            Form {
                TextField("Cliente", text: $m.cliente, prompt: Text("es. Luigi Mastroianni"))
                TextField("Evento", text: $m.evento, prompt: Text("AAMMGG_NomeEvento"))
                if !m.evento.isEmpty && !m.formatoOk {
                    Text("Senza il formato AAMMGG_ Lightroom non ritrova le foto scelte.")
                        .font(.caption).foregroundStyle(.orange)
                }
                TextField("Password", text: $m.password, prompt: Text("scrivila o usa quella proposta"))
                TextField("Max selezioni", text: $m.maxTesto, prompt: Text("0 = nessun limite"))
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, -20)
            .frame(height: m.formatoOk || m.evento.isEmpty ? 190 : 218)

            Button(action: m.avvia) {
                Text("Crea e pubblica").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!m.pronto)
        }
    }

    func lavoro(_ testo: String, _ fatto: Int, _ totale: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(m.evento).font(.headline)
            if totale > 0 {
                ProgressView(value: Double(fatto), total: Double(totale))
                Text(totale > 1 ? "\(testo) — \(fatto)/\(totale)" : "\(testo)…").foregroundStyle(.secondary)
            } else {
                ProgressView().progressViewStyle(.linear)
                Text(testo).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 120)
    }

    func fatto(_ link: String, _ messaggio: String, _ foto: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Galleria pubblicata — \(foto) foto", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
            Text("Il messaggio per il cliente è già negli appunti.").foregroundStyle(.secondary)
            Text(messaggio)
                .textSelection(.enabled)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            HStack {
                Button("Copia di nuovo") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(messaggio, forType: .string)
                }
                Button("Apri galleria") { NSWorkspace.shared.open(URL(string: link)!) }
                Button("WhatsApp") {
                    var c = URLComponents(string: "https://wa.me/")!
                    c.queryItems = [URLQueryItem(name: "text", value: messaggio)]
                    NSWorkspace.shared.open(c.url!)
                }
                Spacer()
                Button("Nuova") { m.cartella = nil; m.cliente = ""; m.evento = ""; m.password = ""; m.maxTesto = "0"; m.fase = .compila }
                    .keyboardShortcut(.defaultAction)
            }
            Text("Il sito si aggiorna in 1–2 minuti dopo la pubblicazione.").font(.caption).foregroundStyle(.secondary)
        }
    }

    func errore(_ testo: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Qualcosa è andato storto", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            ScrollView {
                Text(testo).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            Button("Indietro") { m.fase = .compila }.keyboardShortcut(.defaultAction)
        }
    }
}

// Cartella trascinata sull'icona nel Dock
final class Delegato: NSObject, NSApplicationDelegate {
    var modello: Modello?
    func application(_ application: NSApplication, open urls: [URL]) {
        if let u = urls.first { Task { @MainActor in self.modello?.impostaCartella(u) } }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct GalleriaClientiApp: App {
    @NSApplicationDelegateAdaptor(Delegato.self) var delegato
    @StateObject private var modello = Modello()

    var body: some Scene {
        Window("Galleria Clienti", id: "main") {
            Contenuto()
                .environmentObject(modello)
                .onAppear { delegato.modello = modello }
        }
        .windowResizability(.contentSize)
    }
}
