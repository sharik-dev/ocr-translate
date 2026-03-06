import SwiftUI

struct ExtensionsListView: View {
    @EnvironmentObject var extensionManager: ExtensionManager
    @State private var searchQuery = ""
    
    var filteredExtensions: [RepoExtension] {
        if searchQuery.isEmpty {
            return extensionManager.availableExtensions
        } else {
            return extensionManager.availableExtensions.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Repository Settings")) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                        TextField("https://.../index.min.json", text: $extensionManager.customRepoURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                Task { await extensionManager.fetchRepository() }
                            }
                        
                        if !extensionManager.customRepoURL.isEmpty {
                            Button(action: {
                                extensionManager.customRepoURL = ""
                                extensionManager.availableExtensions = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Button(action: {
                        Task { await extensionManager.fetchRepository() }
                    }) {
                        HStack {
                            Spacer()
                            if extensionManager.isLoadingRepo {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Load Repository")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(extensionManager.customRepoURL.isEmpty || extensionManager.isLoadingRepo)
                }
                
                if let error = extensionManager.errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if !extensionManager.availableExtensions.isEmpty {
                    Section(header: Text("Available Extensions (\(filteredExtensions.count))")) {
                        ForEach(filteredExtensions) { ext in
                            if let sources = ext.sources {
                                ForEach(sources) { source in
                                    ExtensionSourceRow(source: source, extName: ext.name)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Extensions")
            .searchable(text: $searchQuery, prompt: "Search Extensions")
            .refreshable {
                if !extensionManager.customRepoURL.isEmpty {
                    await extensionManager.fetchRepository()
                }
            }
            .onAppear {
                if extensionManager.availableExtensions.isEmpty && !extensionManager.customRepoURL.isEmpty && !extensionManager.isLoadingRepo {
                    Task {
                        await extensionManager.fetchRepository()
                    }
                }
            }
        }
    }
}

struct ExtensionSourceRow: View {
    let source: SourceDescriptor
    let extName: String
    @EnvironmentObject var extensionManager: ExtensionManager
    
    var body: some View {
        let isInstalled = extensionManager.isInstalled(source: source)
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(source.lang.uppercased())
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray.opacity(0.2)))
                    
                    Text(extName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    extensionManager.toggleInstall(source: source)
                }
            }) {
                Text(isInstalled ? "Remove" : "Install")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isInstalled ? Color.gray.opacity(0.2) : Color.accentColor.opacity(0.1))
                    .foregroundColor(isInstalled ? .red : .accentColor)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 4)
    }
}


