
import SwiftUI
import Combine


// 课程大纲中的每个子项
struct OutlineItem: Identifiable, Codable {
    let id: Int // 外部指定的唯一标识符
    var subTitle: String
    var content: String
    var status: Int // 0: 未学习, 1: 正在学习, 2: 已完成学习
    
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

// VIEW
struct CourseView: View {
    @EnvironmentObject var courseDataManager: CourseDataManager

    var body: some View {
        NavigationView {
            List {
                if courseDataManager.courses.isEmpty {
                    Text("课程内容未准备好")
                        .foregroundColor(.gray)
                } else {
                    ForEach(courseDataManager.courses) { course in
                        NavigationLink(destination: CourseDetailView(course: course)) {
                            Text(course.title)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("课程列表")
        }
    }
}

// 课程详情视图
struct CourseDetailView: View {
    let course: Course

    var body: some View {
        List {
            ForEach(course.outline) { outlineItem in
                VStack(alignment: .leading, spacing: 8) {
                    Text(outlineItem.subTitle)
                        .font(.headline)
                    Text(outlineItem.content)
                        .font(.body)
                    StatusView(status: outlineItem.status)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(course.title)
    }
}



// 状态视图
struct StatusView: View {
    let status: Int

    var body: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .padding(4)
                .background(statusColor)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }

    private var statusText: String {
        switch status {
        case 0:
            return "未学习"
        case 1:
            return "正在学习"
        case 2:
            return "已完成"
        default:
            return "未知状态"
        }
    }

    private var statusColor: Color {
        switch status {
        case 0:
            return .gray
        case 1:
            return .blue
        case 2:
            return .green
        default:
            return .red
        }
    }
}

//CourseDataManager
class CourseDataManager: ObservableObject {
    @Published var courses: [Course] = []
    
    private let fileName = "courses.json"
    
    // 获取文档目录路径
    private var fileURL: URL {
        let manager = FileManager.default
        let urls = manager.urls(for: .documentDirectory, in: .userDomainMask)
        print("保存课程数据的路径：\(urls[0])")
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
                DispatchQueue.main.async {
                    self.courses = []
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
                print("保存课程数据成功: \(self.fileURL)")
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
}



