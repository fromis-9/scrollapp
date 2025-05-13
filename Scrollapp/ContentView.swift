//
//  ContentView.swift
//  Scrollapp
//

import SwiftUI

struct ContentView: View {
    @State private var isAutoScrollActive = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.and.down.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            Text("Scrollapp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            
            Text("Windows-style auto-scroll")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical, 10)
            
            VStack(alignment: .leading, spacing: 15) {
                HowToUseRow(number: "1", text: "Middle-click anywhere")
                HowToUseRow(number: "2", text: "Move mouse up/down to control speed")
                HowToUseRow(number: "3", text: "Click again to stop scrolling")
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.horizontal, 10)
                
                Button("About") {
                    // Show about information - could open a URL or display a sheet
                    let aboutURL = URL(string: "https://example.com/scrollapp")
                    if let url = aboutURL {
                        openURL(url)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 10)
        }
        .padding()
        .frame(width: 320, height: 400)
    }
}

struct HowToUseRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 14))
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
