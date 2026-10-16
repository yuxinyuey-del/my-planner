//
//  WelcomeView.swift
//  My Planner
//
//  Created by Jessie yu on 2026/05/12.
//

import SwiftUI

struct WelcomeView: View {
    @State private var store = GoalsStore()
    @State private var newGoalText = ""
    @State private var showingAddGoal = false

    // Get a greeting based on time of day
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting + " 🌸")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("Welcome back.")
                            .font(.largeTitle.bold())

                        Text("Don't forget your goal.")
                            .font(.title3)
                            .foregroundStyle(.pink)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                    // ── Goals section ─────────────────────────────────
                    HStack {
                        Text("My Goals")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        Spacer()
                        Text("\(store.goals.filter { $0.isCompleted }.count)/\(store.goals.count) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // ── Goals list ────────────────────────────────────
                    if store.goals.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Text("✨")
                                .font(.system(size: 40))
                            Text("Add your first goal below")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.goals) { goal in
                                GoalRowView(goal: goal) {
                                    store.toggle(goal)
                                }
                            }
                            .onDelete { store.delete(at: $0) }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Add goal button ───────────────────────────────
                    Button {
                        showingAddGoal = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.pink)
                            Text("Add a goal")
                                .foregroundStyle(.pink)
                            Spacer()
                        }
                        .padding()
                        .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                }
                .padding(.bottom, 40)
            }
            .background(.gray.opacity(0.1))
            .toolbar(.hidden, for: .navigationBar)
        }
        // ── Add goal sheet ────────────────────────────────────────────
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet(isPresented: $showingAddGoal) { text in
                store.add(text)
            }
        }
    }
}

// ── Single goal row ───────────────────────────────────────────────────
struct GoalRowView: View {
    let goal: Goal
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(goal.isCompleted ? .pink : .secondary)
                    .animation(.spring(duration: 0.25), value: goal.isCompleted)
            }

            // Goal text
            Text(goal.title)
                .font(.body)
                .strikethrough(goal.isCompleted, color: .secondary)
                .foregroundStyle(goal.isCompleted ? .secondary : .primary)
                .animation(.easeInOut(duration: 0.2), value: goal.isCompleted)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

#Preview {
    WelcomeView()
}
