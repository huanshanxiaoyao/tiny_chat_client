import Foundation

// 定义一个全局的网络请求函数
func postRequest(urlString: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
    // 验证 URL 是否有效
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // 将参数转为 JSON 数据
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
    } catch {
        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "参数序列化失败：\(error.localizedDescription)"])))
        return
    }
    
    // 创建一个自定义的 URLSession，使用自定义的 URLSessionDelegate
    let session = URLSession(configuration: .default, delegate: MyURLSessionDelegate(), delegateQueue: nil)
    
    // 执行网络请求
    session.dataTask(with: request) { data, response, error in
        // 检查是否有错误
        if let error = error {
            completion(.failure(error))
            return
        }
        
        // 检查状态码是否成功
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
        }
        
        // 解析响应数据
        guard let data = data else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "没有接收到数据"])))
            return
        }
        
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                completion(.success(jsonResponse))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应格式"])))
            }
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// 自定义 URLSessionDelegate 来信任自签名证书
class MyURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            // 使用服务器的信任对象来创建一个 URL 凭证
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

