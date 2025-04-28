//
//  CalendarView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/4/28.
//

import SwiftUI

struct CalendarView: View {
    @State private var selectedDates: Set<Date> = []
    @State private var currentPage: Int = 0
    
    private let calendar = Calendar.current
    private let today = Date()
    private let monthsRange = -60...60
    
    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $currentPage) {
                ForEach(monthsRange, id: \.self) { offset in
                    CalendarMonthView(
                        monthOffset: offset,
                        selectedDates: $selectedDates
                    )
                    .frame(width: UIScreen.main.bounds.width - 32,
                           height: CalendarMonthView.dynamicHeightForMonth(offset: offset))
                    .background(Color.gray.opacity(0.1))
                    .tag(offset)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .onAppear {
            currentPage = 0
        }
        .padding(16)
    }
}

struct CalendarMonthView: View {
    let monthOffset: Int
    @Binding var selectedDates: Set<Date>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    private static let rowHeight: CGFloat = 44 // 每一排的高度
    private static let headerHeight: CGFloat = 40 // 星期幾的高度 + 標題高度

    private var monthDate: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date())!
    }
    
    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        var dates: [Date] = []
        var date = monthInterval.start
        while date < monthInterval.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }
    
    private var startWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: calendar.dateInterval(of: .month, for: monthDate)!.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    private var numberOfRows: Int {
        let totalItems = startWeekdayOffset + monthDays.count
        return Int(ceil(Double(totalItems) / 7.0))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 月份標題
            Text(monthYearText(monthDate))
                .font(.title2)
                .bold()

            // 星期標題
            HStack {
                ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 日期格子
            LazyVGrid(columns: columns, spacing: 8) {
                // 空白補位
                ForEach(0..<startWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(height: 40)
                }
                
                // 實際日期
                ForEach(monthDays, id: \.self) { date in
                    let day = calendar.component(.day, from: date)
                    Text("\(day)")
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            ZStack {
                                if calendar.isDate(date, inSameDayAs: Date()) {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                }
                                if selectedDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.3))
                                }
                            }
                        )
                        .clipShape(Circle())
                        .onTapGesture {
                            toggleSelection(for: date)
                        }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private func toggleSelection(for date: Date) {
        if let existing = selectedDates.first(where: { calendar.isDate($0, inSameDayAs: date) }) {
            selectedDates.remove(existing)
        } else {
            selectedDates.insert(date)
        }
    }
    
    private func monthYearText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMMM"
        return formatter.string(from: date)
    }
    
    // 這個是 static function 給外面 CalendarView 用的
    static func dynamicHeightForMonth(offset: Int) -> CGFloat {
        let calendar = Calendar.current
        guard let monthDate = calendar.date(byAdding: .month, value: offset, to: Date()),
              let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return 400
        }
        
        let startWeekdayOffset = (calendar.component(.weekday, from: monthInterval.start) - calendar.firstWeekday + 7) % 7
        var dates = 0
        var date = monthInterval.start
        while date < monthInterval.end {
            dates += 1
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        let totalItems = startWeekdayOffset + dates
        let numberOfRows = Int(ceil(Double(totalItems) / 7.0))
        
        // header + 每行高度 * 行數
        return headerHeight + (rowHeight * CGFloat(numberOfRows))
    }
}
