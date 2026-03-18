import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct SyllabusImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    enum InputMode: String, CaseIterable {
        case paste = "Paste Text"
        case file  = "Pick File"
    }

    @State private var inputMode: InputMode = .paste
    @State private var pastedText   = ""
    @State private var extractedText = ""
    @State private var fileName      = ""
    @State private var showFilePicker = false

    @State private var isParsing = false
    @State private var parsed: ParsedSyllabus?
    @State private var isImporting = false

    @State private var alertMessage = ""
    @State private var showAlert    = false
    @State private var showApiKey   = false
    @State private var tempKey      = ""

    private var activeText: String { inputMode == .paste ? pastedText : extractedText }

    // Preset colors for auto-assignment
    private let colors = ["4361ee","f72585","7209b7","3a0ca3","4cc9f0","06d6a0","ff6b6b"]

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Input", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // Input
                if inputMode == .paste {
                    Section("Paste Syllabus Text") {
                        TextEditor(text: $pastedText)
                            .frame(minHeight: 160)
                            .font(.system(.footnote, design: .monospaced))
                    }
                } else {
                    Section("Select File") {
                        if fileName.isEmpty {
                            Button {
                                showFilePicker = true
                            } label: {
                                Label("Choose PDF or Text File", systemImage: "doc.badge.plus")
                            }
                        } else {
                            HStack {
                                Image(systemName: "doc.text.fill").foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(fileName).font(.subheadline).fontWeight(.medium)
                                    Text("\(extractedText.count) characters extracted")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Change") { showFilePicker = true }.font(.caption)
                            }
                        }
                    }
                }

                // Parse button
                if !activeText.isEmpty && parsed == nil {
                    Section {
                        Button {
                            Task { await doParse() }
                        } label: {
                            if isParsing {
                                HStack {
                                    SwiftUI.ProgressView().padding(.trailing, 4)
                                    Text("Analyzing…")
                                }
                            } else {
                                Label("Analyze with AI", systemImage: "sparkles")
                            }
                        }
                        .disabled(isParsing)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                // Preview
                if let s = parsed {
                    Section("Course Info") {
                        LabeledContent("Code",      value: s.course.courseCode)
                        LabeledContent("Title",     value: s.course.title)
                        LabeledContent("Term",      value: s.course.term)
                        LabeledContent("Professor", value: s.course.professorName)
                        if let t = s.course.meetingTimes { LabeledContent("Schedule", value: t) }
                        if let l = s.course.location     { LabeledContent("Location", value: l) }
                    }

                    Section("Assignments (\(s.assignments.count))") {
                        ForEach(s.assignments) { a in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(a.title).font(.subheadline).fontWeight(.semibold)
                                    Spacer()
                                    Text("\(a.totalPoints) pts").font(.caption).foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Text(a.type.capitalized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                    Text("Due \(formattedDate(a.dueDateString))")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section {
                        Button {
                            Task { await doImport() }
                        } label: {
                            if isImporting {
                                HStack {
                                    SwiftUI.ProgressView().padding(.trailing, 4)
                                    Text("Importing…")
                                }
                            } else {
                                Label("Save Course & Assignments", systemImage: "square.and.arrow.down")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isImporting)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Section {
                        Button("Re-analyze", role: .destructive) { parsed = nil }
                    }
                }
            }
            .navigationTitle("Import Syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { tempKey = GroqService.shared.apiKey; showApiKey = true } label: {
                        Image(systemName: "key")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, .text,
                                      UTType(filenameExtension: "docx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleFile(result)
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showApiKey) {
                GroqApiKeyView(apiKey: $tempKey) {
                    GroqService.shared.apiKey = tempKey
                    showApiKey = false
                }
            }
        }
    }

    // MARK: - File handling

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            do {
                if ext == "pdf" {
                    extractedText = try extractPDF(url)
                } else if ext == "docx" {
                    guard let text = try? extractDOCX(url), !text.isEmpty else {
                        showError("DOCX parsing failed. Open in Pages/Word, share as PDF, or use Paste Text.")
                        return
                    }
                    extractedText = text
                } else {
                    extractedText = try String(contentsOf: url, encoding: .utf8)
                }
                parsed = nil
            } catch {
                showError(error.localizedDescription)
            }
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    private func extractPDF(_ url: URL) throws -> String {
        guard let doc = PDFDocument(url: url) else {
            throw NSError(domain: "PDF", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Could not open PDF"])
        }
        return (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
    }

    /// Minimal DOCX text extractor: parse ZIP structure, find word/document.xml,
    /// decompress (DEFLATE method 8), strip XML tags.
    private func extractDOCX(_ url: URL) throws -> String {
        let data  = try Data(contentsOf: url)
        let bytes = [UInt8](data)
        var i = 0
        while i + 30 < bytes.count {
            guard bytes[i]==0x50, bytes[i+1]==0x4B, bytes[i+2]==0x03, bytes[i+3]==0x04
            else { i += 1; continue }

            let compression = UInt16(bytes[i+8])  | (UInt16(bytes[i+9])  << 8)
            let compSize    = readU32(bytes, i+18)
            let uncompSize  = readU32(bytes, i+22)
            let nameLen     = Int(UInt16(bytes[i+26]) | (UInt16(bytes[i+27]) << 8))
            let extraLen    = Int(UInt16(bytes[i+28]) | (UInt16(bytes[i+29]) << 8))
            let headerEnd   = i + 30 + nameLen + extraLen
            guard headerEnd <= bytes.count else { break }

            let name = String(bytes: Array(bytes[(i+30)..<(i+30+nameLen)]), encoding: .utf8) ?? ""

            if name == "word/document.xml" {
                let start = headerEnd
                let end   = start + Int(compSize)
                guard end <= bytes.count else { break }
                let compressed = Data(bytes[start..<end])

                let xmlData: Data
                if compression == 0 {
                    xmlData = compressed
                } else if compression == 8 {
                    // Wrap raw DEFLATE in zlib envelope (0x78 0x9C header)
                    var wrapped = Data([0x78, 0x9C])
                    wrapped.append(compressed)
                    wrapped.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // dummy Adler-32
                    guard let result = try? (wrapped as NSData).decompressed(using: .zlib) as Data
                    else { break }
                    xmlData = result
                } else { break }

                let xml = String(data: xmlData, encoding: .utf8) ?? ""
                return stripXML(xml)
            }
            i = headerEnd + Int(compSize)
        }
        return ""
    }

    private func readU32(_ b: [UInt8], _ idx: Int) -> UInt32 {
        UInt32(b[idx]) | (UInt32(b[idx+1])<<8) | (UInt32(b[idx+2])<<16) | (UInt32(b[idx+3])<<24)
    }

    private func stripXML(_ xml: String) -> String {
        var s = xml.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (e, r) in [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&apos;","'"),("&quot;","\"")] {
            s = s.replacingOccurrences(of: e, with: r)
        }
        return s.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}.joined(separator: " ")
    }

    // MARK: - Parse & Import

    private func doParse() async {
        if !GroqService.shared.hasApiKey {
            tempKey = ""; showApiKey = true; return
        }
        isParsing = true
        defer { isParsing = false }
        do {
            parsed = try await GroqService.shared.parseSyllabus(text: activeText)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func doImport() {
        guard let s = parsed else { return }
        isImporting = true

        let course = LocalCourse(
            courseCode:        s.course.courseCode,
            title:             s.course.title,
            courseDescription: s.course.description,
            professorName:     s.course.professorName,
            term:              s.course.term,
            meetingTimes:      s.course.meetingTimes,
            location:          s.course.location,
            color:             colors[abs(s.course.courseCode.hashValue) % colors.count]
        )
        context.insert(course)

        for a in s.assignments {
            let assignment = LocalAssignment(
                title:       a.title,
                description: a.description,
                dueDate:     a.dueDate,
                type:        a.validType,
                totalPoints: a.totalPoints,
                course:      course
            )
            context.insert(assignment)
        }

        isImporting = false
        dismiss()
    }

    // MARK: - Helpers

    private func showError(_ msg: String) { alertMessage = msg; showAlert = true }

    private func formattedDate(_ str: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: str) else { return str }
        df.dateStyle = .medium; df.timeStyle = .none
        return df.string(from: d)
    }
}

// MARK: - API Key Sheet

struct GroqApiKeyView: View {
    @Binding var apiKey: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("gsk_…", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Groq API Key")
                } footer: {
                    Text("Free at console.groq.com. Stored only on this device, never sent anywhere except Groq.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }.disabled(apiKey.isEmpty)
                }
            }
        }
    }
}
