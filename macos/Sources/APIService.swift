import Foundation

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    private let baseURL = "http://localhost:5001/api"
    
    @Published var isAuthenticated = false
    @Published var token: String? {
        didSet {
            UserDefaults.standard.set(token, forKey: "authToken")
            isAuthenticated = token != nil
        }
    }
    
    init() {
        self.token = UserDefaults.standard.string(forKey: "authToken")
        self.isAuthenticated = self.token != nil
    }
    
    // MARK: - Auth
    
    func login(email: String, password: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        guard httpResponse.statusCode == 200 else {
             throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Login failed"])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            self.token = token
            return true
        }
        return false
    }
    
    func signup(email: String, password: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/auth/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
             if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = json["message"] as? String {
                 throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
             }
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Signup failed"])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            self.token = token
            return true
        }
        return false
    }
    
    func logout() {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
    
    // MARK: - Sync
    
    struct NoteUpdate: Codable {
        let localId: String
        let content: String // HTML
        let version: Int
        let isDeleted: Bool
    }
    
    struct SyncResponse: Codable {
        let changes: [ServerNote]
        let serverTime: String
    }
    
    struct ServerNote: Codable {
        let localId: String
        let content: String
        let version: Int
        let isDeleted: Bool
        let updatedAt: String
    }
    
    func sync(changes: [NoteUpdate], lastSyncTimestamp: String?) async throws -> (changes: [ServerNote], serverTime: String) {
        let url = URL(string: "\(baseURL)/notes/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "changes": changes.map { [
                "localId": $0.localId,
                "content": $0.content,
                "version": $0.version,
                "isDeleted": $0.isDeleted
            ] },
            "lastSyncTimestamp": lastSyncTimestamp as Any
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Sync", code: 0, userInfo: [NSLocalizedDescriptionKey: "Sync failed"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(SyncResponse.self, from: data)
        return (result.changes, result.serverTime)
    }
    
    // MARK: - Image Upload
    
    func uploadImage(data: Data) async throws -> String {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Upload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image upload failed"])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let imageUrl = json["url"] as? String {
            return imageUrl
        }
        throw NSError(domain: "Upload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
}
