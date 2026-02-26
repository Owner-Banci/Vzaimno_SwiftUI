import SwiftUI

struct MapScreen: View {
    @StateObject private var vm: MapViewModel
    private let mapMode: MapDisplayMode

    init(
        vm: MapViewModel,
        mapMode: MapDisplayMode = MapDisplayConfig.defaultMode()
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.mapMode = mapMode
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapArea

            VStack(spacing: 5) {
                Spacer().frame(height: 50)
                searchBar
                errorLabel
                chipsRow
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .ignoresSafeArea()
        }
        .task {
            await vm.reloadPins()
        }
        .sheet(item: $vm.selectedAnnouncement, onDismiss: {
            vm.clearSelection()
        }) { announcement in
            AnnouncementSheetView(announcement: announcement)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.ColorToken.textSecondary)

            TextField("Введите адрес", text: $vm.searchText, onCommit: vm.performSearch)
                .textFieldStyle(.plain)

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.ColorToken.textSecondary)
                        .imageScale(.medium)
                }
            }

            Button(action: vm.performSearch) {
                Text("Найти")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .softCardShadow()
    }

    private var errorLabel: some View {
        Group {
            if let message = vm.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(vm.chips, id: \.self) { chip in
                    FilterChip(
                        title: chip,
                        isSelected: Binding(
                            get: { vm.selected.contains(chip) },
                            set: { isOn in
                                if isOn { vm.selected.insert(chip) }
                                else { vm.selected.remove(chip) }
                            }
                        )
                    )
                }
            }
        }
    }

    private var mapArea: some View {
        MapCanvasView(
            centerPoint: $vm.centerPoint,
            pins: vm.pins,
            selectedPinID: vm.selectedPinID,
            routePolyline: vm.routePolyline,
            shouldFitRoute: vm.shouldFitRoute,
            onRouteFitted: vm.consumeRouteFitRequest,
            onPinTap: { pinID in
                Task { @MainActor in
                    await vm.selectAnnouncement(pinID: pinID)
                }
            },
            mode: mapMode
        )
            .ignoresSafeArea(edges: .top)
    }
}
