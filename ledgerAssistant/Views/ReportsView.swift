import SwiftUI

struct ReportsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Toggle
                HStack(spacing: 0) {
                    Button(action: { viewModel.reportType = "expense" }) {
                        Text("花費")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 80, height: 32)
                            .background(viewModel.reportType == "expense" ? Color.white : Color.gray.opacity(0.1))
                            .foregroundColor(viewModel.reportType == "expense" ? .orange : .gray)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { viewModel.reportType = "income" }) {
                        Text("收入")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 80, height: 32)
                            .background(viewModel.reportType == "income" ? Color.white : Color.gray.opacity(0.1))
                            .foregroundColor(viewModel.reportType == "income" ? .green : .gray)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(2)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .comicBorder(width: 3, cornerRadius: 6)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Total Amount
                    HStack {
                        Spacer()
                        Text(viewModel.reportType == "expense" ? viewModel.monthlyExpense : viewModel.monthlyIncome)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    // Pie Chart
                    MangaPieChart(segments: viewModel.chartSegments)
                        .frame(width: 280, height: 280)
                        .padding(.vertical, 10)
                    
                    // Date Selector and Divider
                    VStack(spacing: 8) {
                        HStack {
                            Button(action: { viewModel.prevMonth() }) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            Text("\(String(viewModel.selectedYear))年\(viewModel.selectedMonth + 1)月")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Button(action: { viewModel.nextMonth() }) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 3)
                            .comicBorder(width: 1, cornerRadius: 0)
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 16) {
                        ForEach(viewModel.categoryStats) { stat in
                            if stat.amount > 0 {
                                CategoryProgressBar(
                                    category: stat.category.rawValue,
                                    icon: stat.category.icon,
                                    amount: "$\(Int(stat.amount))",
                                    proportion: stat.proportion,
                                    color: stat.category.color,
                                    change: stat.change
                                )
                                .padding(12)
                                .background(Color.white)
                                .comicBorder(width: 2, cornerRadius: 10)
                            }
                        }
                        
                        if viewModel.categoryStats.filter({ $0.amount > 0 }).isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.2))
                                Text("本月尚無資料")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
        }
        .background(
            ZStack {
                Color.white
                DotPattern(opacity: 0.05)
            }.ignoresSafeArea()
        )
    }
}

#Preview {
    ReportsView(viewModel: DashboardViewModel())
}
