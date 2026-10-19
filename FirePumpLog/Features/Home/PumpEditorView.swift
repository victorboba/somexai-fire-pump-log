import SwiftUI
import SwiftData

/// The pump's nameplate and identity — most of what every later test is measured against.
struct PumpEditorView: View {
    @Bindable var pump: Pump
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Pump") {
                    TextField("Designation (e.g. Fire Pump 1)", text: $pump.designation)
                        .accessibilityIdentifier("pumpDesignationField")
                    TextField("Building", text: $pump.building)
                    TextField("Location (e.g. Basement pump room)", text: $pump.location)
                    TextField("Make", text: $pump.make)
                    TextField("Model", text: $pump.model)
                    TextField("Serial number", text: $pump.serialNumber)
                }

                Section {
                    LabeledContent("Rated flow") {
                        HStack(spacing: 4) {
                            TextField("—", value: $pump.ratedFlowGPM, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("ratedFlowField")
                            Text("gpm").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Rated pressure") {
                        HStack(spacing: 4) {
                            TextField("—", value: $pump.ratedPressurePSI, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("ratedPressureField")
                            Text("psi").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Rated speed") {
                        HStack(spacing: 4) {
                            TextField("—", value: $pump.ratedRPM, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("rpm").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Nameplate")
                } footer: {
                    Text("The annual flow test is measured against these three numbers. Photograph the nameplate while you are at the pump.")
                }

                Section {
                    ChoiceChips(options: DriverType.allCases, selection: $pump.driver, title: \.name)
                } header: {
                    Text("Driver")
                } footer: {
                    Text(pump.driver.asksEngineReadings
                         ? "A diesel test also asks for fuel level, both battery voltages, oil pressure and coolant temperature."
                         : "An electric pump is never asked about fuel, batteries, oil or coolant.")
                }

                Section {
                    TextField("Controller make", text: $pump.controllerMake)
                    TextField("Controller model", text: $pump.controllerModel)
                }

                Section {
                    ChoiceChips(options: ChurnCadence.allCases, selection: $pump.churnCadence, title: \.name)
                } header: {
                    Text("No-flow test cadence")
                } footer: {
                    Text("Electric and diesel pumps have historically differed on weekly-versus-monthly. Set what your authority having jurisdiction or insurer actually requires; every test records the cadence in force when it was run.")
                }

                Section {
                    Toggle("Has a jockey pump", isOn: $pump.hasJockeyPump)
                    if pump.hasJockeyPump {
                        LabeledContent("Cut-in setpoint") {
                            HStack(spacing: 4) {
                                TextField("—", value: $pump.jockeyCutInSetpointPSI, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("psi").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Cut-out setpoint") {
                            HStack(spacing: 4) {
                                TextField("—", value: $pump.jockeyCutOutSetpointPSI, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("psi").foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Jockey pump")
                }

                Section("Photo") {
                    PhotoField(data: $pump.photoData, label: "Photo of the pump or its nameplate")
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $pump.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Delete This Pump", role: .destructive) {
                        context.delete(pump)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Pump Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
