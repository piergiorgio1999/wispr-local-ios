import SwiftUI
import UniformTypeIdentifiers
import UIKit
import WhisperBackend

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var isSelectingFile = false
    @State private var selectionKind: SelectionKind = .model
    @State private var showingError = false

    private enum SelectionKind: Equatable {
        case model
        case course

        var allowedContentTypes: [UTType] {
            self == .model ? [.data] : [.folder]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    selectionCard
                    courseCard
                    runCard
                    footer
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Wispr Local")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $isSelectingFile, allowedContentTypes: selectionKind.allowedContentTypes) { result in
                handleSelection(result, isModel: selectionKind == .model)
            }
            .onChange(of: state.errorMessage) { message in showingError = message != nil }
            .onChange(of: state.isRunning) { UIApplication.shared.isIdleTimerDisabled = $0 }
            .alert("Operazione non riuscita", isPresented: $showingError) {
                Button("OK") { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? "Riprova selezionando nuovamente il file o la cartella.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trascrivi le lezioni direttamente su iPad")
                .font(.title2.bold())
            Text("Audio e modello restano sul dispositivo. Wispr scrive i file raw della trascrizione nella cartella di ogni lezione.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Modello Whisper", systemImage: state.modelReady ? "checkmark.circle.fill" : "cpu")
                .font(.headline)
            Text(state.modelName ?? "Nessun modello selezionato")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            Button("Scegli ggml-large-v3.bin") {
                selectionKind = .model
                isSelectingFile = true
            }
                .buttonStyle(.bordered)
                .disabled(state.isRunning || state.isLoadingModel)
            if state.isLoadingModel {
                ProgressView("Caricamento del modello in memoria…")
            } else if state.modelReady {
                Label("Modello caricato e pronto", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text("large-v3 occupa circa 3 GB su disco e richiede molta memoria. Il tempo dipende dalla durata della lezione e non è garantito che sia più rapido del Mac.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Cartella del corso", systemImage: "folder")
                    .font(.headline)
                Spacer()
                Button("Scegli") {
                    selectionKind = .course
                    isSelectingFile = true
                }
                    .buttonStyle(.bordered)
                    .disabled(state.isRunning)
            }
            Text(state.courseName ?? "Seleziona la cartella che contiene le lezioni")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            HStack(spacing: 10) {
                countBadge("Da fare", count: state.pendingCount, color: .blue)
                countBadge("Con VTT", count: state.transcribedCount, color: .green)
                countBadge("Senza audio", count: state.missingAudioCount, color: .orange)
            }
            .accessibilityElement(children: .combine)
            if !state.lessons.isEmpty {
                Button("Aggiorna elenco") { state.refreshLessons() }
                    .font(.subheadline)
                    .disabled(state.isRunning)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var runCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Coda di trascrizione", systemImage: "waveform")
                .font(.headline)
            if let progress = state.progress, state.isRunning {
                Text(progress.lessonTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                ProgressView(value: progress.fraction)
                    .accessibilityLabel("Avanzamento trascrizione lezione")
                Text("\(stageTitle(progress.stage)) · \(progress.completedLessons) di \(progress.totalLessons) lezioni completate")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if state.isRunning {
                ProgressView("Preparazione coda…")
            }
            if let summary = state.summary {
                Label("Sessione terminata: \(summary.transcribed) trascritte, \(summary.skipped) saltate.", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
            }
            if let statusMessage = state.statusMessage {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    state.startBatch()
                } label: {
                    Label("Avvia trascrizione", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.modelReady || state.courseName == nil || state.pendingCount == 0 || state.isRunning)
                if state.isRunning {
                    Button(role: .destructive) {
                        state.cancelBatch()
                    } label: {
                        Label("Interrompi", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("Elabora una lezione alla volta, dalle più recenti alle più vecchie. Le trascrizioni VTT già presenti vengono saltate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tieni Wispr aperta e collega l'iPad all'alimentazione.", systemImage: "battery.100percent")
                .font(.footnote.weight(.medium))
            Text("iPadOS può sospendere l'app se passa in background o il dispositivo si blocca. Alla riapertura puoi riprendere: le lezioni che hanno già una trascrizione raw valida saranno saltate. Questo strumento non certifica OCR o completamento del materiale didattico.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private func countBadge(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(count)").font(.title3.bold())
            Text(title).font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("\(title): \(count)")
    }

    private func stageTitle(_ stage: EiducoWorkerProgress.Stage) -> String {
        switch stage {
        case .decodingAudio: "Decodifica audio"
        case .transcribing: "Trascrizione Whisper"
        case .writingFiles: "Salvataggio file"
        }
    }

    private func handleSelection(_ result: Result<[URL], Error>, isModel: Bool) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            if isModel {
                guard url.pathExtension.lowercased() == "bin" else {
                    state.errorMessage = "Scegli il file locale del modello Whisper in formato .bin."
                    return
                }
                state.chooseModel(url)
            } else {
                state.chooseCourse(url)
            }
        case let .failure(error):
            state.errorMessage = error.localizedDescription
        }
    }
}
