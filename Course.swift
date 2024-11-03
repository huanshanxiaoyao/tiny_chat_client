import SwiftUI
import Combine

// 课程大纲中的每个子项
struct OutlineItem: Identifiable, Codable {
    let id: Int // 外部指定的唯一标识符
    var subTitle: String
    var content: String
    var status: Int // 0: 未学习, 1: 正在学习, 2: 已完成学习
    var detailContent: String? // 新增字段，用于保存学习内容
    
    init(id: Int, subTitle: String, content: String, status: Int) {
        self.id = id
        self.subTitle = subTitle
        self.content = content
        self.status = status
    }
}

// 课程模型
struct Course: Identifiable, Codable {
    var id: Int
    var title: String
    var outline: [OutlineItem]
}


class CourseViewModel: ObservableObject {
    @Published var course: Course
    var outlineItems: [OutlineItem]
    @Published var selectedOutlineItem: OutlineItem?
    @Published var alertModel = AlertModel()
    @Published var isLoading = false
    @Published var loadingItemId: Int?
    var courseDataManager: CourseDataManager?
    var studyManager: StudyManager?
    private let courseId: Int

    init(course: Course) {
        self.course = course
        self.outlineItems = course.outline
        self.courseId = course.id
    }

    func startStudy(outlineItemId: Int) {
        guard !isLoading else { return }
        isLoading = true
        loadingItemId = outlineItemId
        
        guard let studyManager = self.studyManager else {
             self.alertModel.alertMessage = "StudyManager 未设置。"
             self.alertModel.showAlert = true
             return
         }

        studyManager.startStudy(courseId: course.id, outlineItemId: outlineItemId) { [weak self] result in
            guard let self = self else { return }
            
            self.isLoading = false
            self.loadingItemId = nil
            
            switch result {
            case .success(let content):
                if let index = self.course.outline.firstIndex(where: { $0.id == outlineItemId }) {
                    self.outlineItems[index].detailContent = content
                    self.outlineItems[index].status = 1
                  
                    self.objectWillChange.send()
                }
            case .failure(let error):
                self.alertModel.alertMessage = "学习请求失败: \(error.localizedDescription)"
                self.alertModel.showAlert = true
            }
        }
    }

    private func showAlert(message: String) {
        alertModel.alertMessage = message
        alertModel.showAlert = true
    }
}

//CourseDataManager
class CourseDataManager: ObservableObject {
    //static let shared = CourseDataManager()
    @Published var courses: [Course] = []
    
    private let fileName = "courses.json"
    
    // 获取文档目录路径
    private var fileURL: URL {
        let manager = FileManager.default
        let urls = manager.urls(for: .documentDirectory, in: .userDomainMask)
        //print("保存课程数据的路径：\(urls[0])")
        return urls[0].appendingPathComponent(fileName)
    }
    
    init() {
        loadCourses()
    }
    
    // 加载课程数据
    func loadCourses() {
        DispatchQueue.global(qos: .background).async {
            let manager = FileManager.default
            if manager.fileExists(atPath: self.fileURL.path) {
                do {
                    let data = try Data(contentsOf: self.fileURL)
                    let decodedCourses = try JSONDecoder().decode([Course].self, from: data)
                    DispatchQueue.main.async {
                        self.courses = decodedCourses
                    }
                } catch {
                    print("加载课程数据失败: \(error)")
                }
            } else {
                // 从服务器获取课程列表
                let url = "\(Config.baseURL)/courselist"
                let parameters: [String: Any] = [
                    "userID": UserModel.shared.userID
                ]
                print("courselist url: \(url)")
                postRequest(urlString: url, parameters: parameters) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let response):
                        if let coursesData = response["data"] as? [[String: Any]] {
                            let courses = coursesData.compactMap { courseDict -> Course? in
                                guard let id = courseDict["courseID"] as? Int,
                                      let title = courseDict["title"] as? String,
                                      let chapters = courseDict["chapters"] as? [[String: Any]] else {
                                    return nil
                                }
                                
                                let outlineItems = chapters.enumerated().compactMap { (index, chapter) -> OutlineItem? in
                                    guard let title = chapter["title"] as? String,
                                          let content = chapter["content"] as? String,
                                          let status = chapter["status"] as? Int else {
                                        return nil
                                    }
                                    return OutlineItem(id: index, subTitle: title, content: content, status: status)
                                }
                                
                                return Course(id: id, title: title, outline: outlineItems)
                            }
                            
                            DispatchQueue.main.async {
                                self.courses = courses
                                self.saveCourses() // 保存到本地
                            }
                        }
                    case .failure(let error):
                        print("获取课程列表失败: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.courses = []
                        }
                    }
                }
            }
        }
    }
    
    // 保存课程数据
    func saveCourses() {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(self.courses)
                try data.write(to: self.fileURL)
            } catch {
                print("保存课程数据失败: \(error)")
            }
        }
    }
    
    // 添加或更新课程
    func addOrUpdateCourse(id: Int, title: String, outlineContent: [OutlineItem]) {
        if let index = courses.firstIndex(where: { $0.id == id }) {
            // 更新已有课程
            courses[index].title = title
            courses[index].outline = outlineContent
        } else {
            // 添加新课程
            let newCourse = Course(id: id, title: title, outline: outlineContent)
            courses.append(newCourse)
        }
        saveCourses()
    }
    
    // 删除课程
    func deleteCourse(course: Course) {
        // 本地删除
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses.remove(at: index)
            saveCourses()
            
            // 发送服务器删除请求
            let url = "\(Config.baseURL)/delete"
            let parameters: [String: Any] = [
                "userID": UserModel.shared.userID,
                "courseID": course.id
            ]
            
            postRequest(urlString: url, parameters: parameters){ result in
                switch result {
                case .success(_):
                    print("课程在服务器端删除成功")
                case .failure(let error):
                    print("删除课程请求失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
