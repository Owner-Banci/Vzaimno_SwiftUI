import SwiftUI

struct ProfileScreen: View {
    @StateObject var vm: ProfileViewModel
    init(vm: ProfileViewModel) { _vm = StateObject(wrappedValue: vm) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header
                settings
                support
                reviews
            }
            .padding(.bottom, 32)
        }
        .background(Theme.ColorToken.milk)
        .navigationTitle("Профиль")
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Circle().fill(Theme.ColorToken.milk).frame(width: 56, height: 56)
                    .overlay(Image(systemName: "person.fill").font(.system(size: 26)).foregroundStyle(Theme.ColorToken.turquoise))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.profile.name).font(.system(size: 20, weight: .semibold))
                    Text(vm.profile.phone).foregroundStyle(Theme.ColorToken.textSecondary)
                        .font(.system(size: 14))
                }
                Spacer()
                Text("ID")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ColorToken.peach.opacity(0.3)))
            }
            
            HStack(spacing: 28) {
                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(Theme.ColorToken.peach)
                        Text("\(vm.profile.rating, specifier: "%.1f")")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Рейтинг").foregroundStyle(Theme.ColorToken.textSecondary).font(.system(size: 12))
                }
                VStack(alignment: .leading) {
                    Text("\(vm.profile.completed)").font(.system(size: 16, weight: .semibold))
                    Text("Выполнено").foregroundStyle(Theme.ColorToken.textSecondary).font(.system(size: 12))
                }
                VStack(alignment: .leading) {
                    Text("\(vm.profile.cancelled)").font(.system(size: 16, weight: .semibold))
                    Text("Отменено").foregroundStyle(Theme.ColorToken.textSecondary).font(.system(size: 12))
                }
                Spacer()
            }
        }
        .padding()
        .background(LinearGradient(colors: [Theme.ColorToken.turquoise.opacity(0.85), Theme.ColorToken.turquoise],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 12)
        .softCardShadow()
    }
    
    private var settings: some View {
        SectionBox(title: "Настройки") {
            ToggleRow(title: "Тёмная тема", isOn: $vm.darkMode)
            NavRow(title: "Уведомления")
            NavRow(title: "Платежи и выплаты")
        }
    }
    
    private var support: some View {
        SectionBox(title: "Поддержка") {
            NavRow(title: "Помощь")
            NavRow(title: "Правила и условия")
        }
    }
    
    private var reviews: some View {
        SectionBox(title: "Отзывы") {
            ForEach(vm.reviews) { r in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(Theme.ColorToken.milk).frame(width: 40, height: 40)
                        .overlay(Text(r.authorInitial).font(.system(size: 16, weight: .bold)))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(r.authorName).font(.system(size: 15, weight: .semibold))
                            StarsView(rating: Double(r.stars))
                            Spacer()
                        }
                        Text(r.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                        Text(r.ago).font(.system(size: 12)).foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            Button("Посмотреть все отзывы") { }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .tint(Theme.ColorToken.turquoise)
                .padding()
        }
    }
}

private struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .padding(.horizontal)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Theme.ColorToken.white))
                .softCardShadow()
                .padding(.horizontal)
        }
        .padding(.top, 4)
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Label(title, systemImage: "moon.fill")
                .labelStyle(.titleAndIcon)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding()
        .background(Color.clear)
    }
}

private struct NavRow: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .padding()
    }
}



#Preview {
    let service = MockProfileService()
    let vm = ProfileViewModel(service: service)
    ProfileScreen(vm: vm)
}

//@StateObject var vm: ProfileViewModel
//init(vm: ProfileViewModel) { _vm = StateObject(wrappedValue: vm) }
