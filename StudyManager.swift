import Foundation
import SwiftUI

class StudyManager: ObservableObject {
    @Published var isLoading = false
    var courseDataManager: CourseDataManager
    init(courseDataManager: CourseDataManager) {
        self.courseDataManager = courseDataManager
    }

    func startStudy(courseId: Int, outlineItemId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        let urlString = "\(Config.baseURL)/study"
        let parameters: [String: Any] = [
            "userID": UserModel.shared.userID,
            "courseID": courseId,
            "outlineitemID": outlineItemId
        ]
        
        postRequest(urlString: urlString, parameters: parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    if let content = response["content"] as? String {
                        self.updateCourseData(courseId: courseId, outlineItemId:outlineItemId,content:content)
                        completion(.success(content))
                    } else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的响应数据"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func updateCourseData(courseId: Int, outlineItemId: Int, content: String) {
        if let courseIndex = courseDataManager.courses.firstIndex(where: { $0.id == courseId }),
           let outlineIndex = courseDataManager.courses[courseIndex].outline.firstIndex(where: { $0.id == outlineItemId }) {
            
            courseDataManager.courses[courseIndex].outline[outlineIndex].detailContent = content
            courseDataManager.courses[courseIndex].outline[outlineIndex].status = 1 // 更新状态为"正在学习"
            
            // 这里不需要手动调用 objectWillChange.send()，因为 @Published 属性会自动处理这个
        }
    }
}
