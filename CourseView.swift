//
//  CourseView.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/21.
//
import SwiftUI

// VIEW
struct CourseView: View {
    @EnvironmentObject var courseDataManager: CourseDataManager
    @EnvironmentObject var studyaManager: StudyManager
    

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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    courseDataManager.deleteCourse(course: course)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
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
    @StateObject private var viewModel: CourseViewModel
    @EnvironmentObject var courseDataManager: CourseDataManager
    @EnvironmentObject var studyManager: StudyManager

    init(course: Course) {
        self.course = course
        _viewModel = StateObject(wrappedValue: CourseViewModel(course: course))
    }

    var body: some View {
        List {
            ForEach(viewModel.outlineItems.sorted(by: { $0.id < $1.id })) { outlineItem in
                VStack(alignment: .leading, spacing: 8) {
                    Text(outlineItem.subTitle)
                        .font(.headline)
                    Text(outlineItem.content)
                        .font(.body)
                    
                    HStack {
                        StatusView(status: outlineItem.status)
                        if outlineItem.status == 0 {
                            if viewModel.isLoading && viewModel.loadingItemId == outlineItem.id {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            } else {
                                Button("开始") {
                                    viewModel.startStudy(outlineItemId: outlineItem.id)
                                }
                                .disabled(viewModel.isLoading)
                            }
                        } else if outlineItem.detailContent != nil {
                            NavigationLink("查看详情", destination: OutlineItemDetailView(content: outlineItem.detailContent ?? ""))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
             viewModel.courseDataManager = courseDataManager
             viewModel.studyManager = studyManager
         }
        .navigationTitle(course.title)
        .alert(isPresented: $viewModel.alertModel.showAlert) {
            Alert(title: Text("提示"), message: Text(viewModel.alertModel.alertMessage), dismissButton: .default(Text("确定")))
        }
    }
}

// 状态视图
struct StatusView: View {
    let status: Int
    
    var body: some View {
        Text(statusText)
            .foregroundColor(statusColor)
    }
    
    private var statusText: String {
        switch status {
        case 0: return "未学习"
        case 1: return "正在学习"
        case 2: return "已完成"
        default: return "未知状态"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case 0: return .red
        case 1: return .blue
        case 2: return .green
        default: return .gray
        }
    }
}

struct OutlineItemDetailView: View {
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .padding()
        }
        .navigationTitle("学习内容")
    }
}
