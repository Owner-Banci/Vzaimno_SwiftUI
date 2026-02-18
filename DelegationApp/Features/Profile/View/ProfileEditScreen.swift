////
////  ProfileEditScreen.swift
////  iCuno test
////
////  Created by maftuna murtazaeva on 23.01.2026.
////
//
//import SwiftUI
//import PhotosUI
//import Foundation
//
//struct UserSettingsView: View {
//    @State private var selectedItem: PhotosPickerItem? = nil
//    @State private var showAgePicker = false
//    @State private var selectedImage: UIImage? = nil
//
//    var body: some View {
//        VStack {
//            HStack { Spacer(); saveButton }
//            ScrollView {
//
//                profileImage
//
//                nicknameSection
//                randomNameButton.padding(.bottom, 20)
//
//                bioSection.padding(.bottom, 20)
//                ageSection.padding(.bottom, 20)
//                
//
//                genderPicker.padding(.bottom, 20)
//                Spacer()
//            }
//        }
////        .onAppear { viewModel.onAppear() }
////        .alert("Сохранено!", isPresented: $viewModel.showSaveBanner) {
////            Button("OK", role: .cancel) {}
////        }
////        .sheet(isPresented: $showAgePicker) { agePicker }
//    }
//
//    private var saveButton: some View {
//        Button("Сохранить") { }
//            .foregroundColor(.red)
//            .padding(.horizontal, 25)
//    }
//
//    
//    var genderPicker: some View {
//        VStack(alignment: .leading) {
//            Text("Ваш пол: Мужской")
//            Text("Укажите свой пол для анкеты")
//                .font(.footnote)
//
//            Picker("", selection: Binding(
//                get: { viewModel.gender },
//                set: { viewModel.genderSelected($0) }
//            )) {
//                ForEach(Gender1.allCases) { g in
//                    Text(g.rawValue).tag(g)
//                }
//            }
//            .pickerStyle(.segmented)
//        }
//        .padding(.horizontal, 25)
//    }
//    
//    var profileImage: some View {
//        VStack {
//            if let image = viewModel.image {
//                Image(uiImage: image)
//                    .resizable()
//                    .frame(width: 130, height: 130)
//                    .cornerRadius(65)
//                    .padding(.top, 25)
//            } else {
//                Text("Изображение не выбрано")
//                    .foregroundColor(.gray)
//                    .padding()
//            }
//
//            PhotosPicker(
//                selection: $selectedItem,
//                matching: .images,
//                photoLibrary: .shared()
//            ) {
//                Text("Изменить фотографию")
//                    .foregroundColor(Color(.label))
//            }
//            .onChange(of: selectedItem) { newItem in
//                Task {
//                    await viewModel.handleImageSelection(newItem)
//                }
//            }
//        }
//        .padding()
//    }
//
//
//    private var nicknameSection: some View {
//        VStack(alignment: .leading) {
//            Text("Никнейм: \(viewModel.name)")
//            Text("Никнейм будет отображён в анкете")
//                .font(.footnote)
//            TextField("Введите никнейм…",
//                      text: Binding(get: { viewModel.name },
//                                     set: viewModel.nameChanged))
//                .textFieldStyle(.roundedBorder)
//                .overlay(RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color(.label).opacity(0.4), lineWidth: 1))
//        }
//        .padding(.horizontal, 25)
//    }
//    private var randomNameButton: some View {
//        Button("СЛУЧАЙНЫЙ НИКНЕЙМ") { viewModel.nicknameTapped() }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 10)
//            .background(Color(.systemGroupedBackground))
//            .cornerRadius(20)
//            .overlay(RoundedRectangle(cornerRadius: 20)
//                .stroke(Color(.label).opacity(0.4), lineWidth: 1))
//            .padding(.horizontal, 25)
//            .foregroundColor(Color(.label))
//    }
//
//
//    private var bioSection: some View {
//        VStack(alignment: .leading) {
//            Text("О себе")
//            Text("Напиши пару слов о себе, чтобы заинтересовать собеседника")
//                .font(.footnote)
//            TextField("О себе",
//                      text: Binding(get: { viewModel.bio },
//                                     set: viewModel.bioChanged))
//                .textFieldStyle(.roundedBorder)
//                .overlay(RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color(.label).opacity(0.4), lineWidth: 1))
//        }
//        .padding(.horizontal, 25)
//    }
//
//    
//    private var ageSection: some View {
//        VStack(alignment: .leading) {
//            Text("Ваш возраст: \(viewModel.age)")
//            Text("Укажите свой возраст для анкеты")
//                .font(.footnote)
//            Button("УКАЖИТЕ ВОЗРАСТ") { showAgePicker = true }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 10)
//                .background(Color(.systemGroupedBackground))
//                .cornerRadius(20)
//                .overlay(RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color(.label).opacity(0.4), lineWidth: 1))
//                .foregroundColor(Color(.label))
//        }
//        .padding(.horizontal, 25)
//    }
//    
//    private var agePicker: some View {
//        VStack(spacing: 0) {
//            Text("Выберите ваш возраст")
//                .font(.headline)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color(.systemGray6))
//            Divider()
//            Picker("Возраст", selection: Binding(
//                get: { viewModel.age },
//                set: viewModel.ageSelected
//            )) {
//                ForEach(10..<100, id: \.self) { Text("\($0)").tag($0) }
//            }
//            .pickerStyle(.wheel)
//            .labelsHidden()
//            .frame(height: 150)
//            Divider()
//            Button("OK") { showAgePicker = false }
//                .frame(maxWidth: .infinity)
//        }
//        .background(Color(.systemBackground))
//        .cornerRadius(16).padding()
//
//
//    }
//}
//
//
//
//
//
////#Preview {
////    UserSettingsModule.build()
////}
