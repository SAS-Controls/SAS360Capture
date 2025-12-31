//
//  Theme.swift
//  SAS360Capture
//
//  SAS Brand colors and styling - matches IO-Link Toolkit design
//

import SwiftUI

// MARK: - Brand Colors
extension Color {
    // Primary brand colors
    static let sasBlue = Color(hex: "2E7DD1")
    static let sasOrange = Color(hex: "E86A33")
    
    // Background colors
    static let sasDarkBg = Color(hex: "1E1E1E")
    static let sasCardBg = Color(hex: "2D2D2D")
    static let sasCardBgHover = Color(hex: "3D3D3D")
    
    // Status colors
    static let sasSuccess = Color(hex: "4CAF50")
    static let sasError = Color(hex: "F44336")
    static let sasWarning = Color(hex: "FF9800")
    
    // Text colors
    static let sasTextPrimary = Color.white
    static let sasTextSecondary = Color(hex: "B0B0B0")
    
    // Border color
    static let sasBorder = Color(hex: "404040")
    
    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - SAS Logo View
struct SASLogo: View {
    var size: CGFloat = 48
    
    var body: some View {
        ZStack {
            // Gear shape
            GearShape()
                .fill(Color.sasBlue)
                .frame(width: size, height: size)
            
            // Inner circle cutout effect
            Circle()
                .fill(Color.sasDarkBg)
                .frame(width: size * 0.55, height: size * 0.55)
            
            // SAS text
            Text("SAS")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(.sasOrange)
        }
    }
}

// MARK: - Gear Shape
struct GearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.7
        let toothDepth = outerRadius * 0.15
        let teeth = 12
        
        for i in 0..<teeth {
            let angle1 = Double(i) * (2 * .pi / Double(teeth))
            let angle2 = angle1 + (0.5 * .pi / Double(teeth))
            let angle3 = angle1 + (1.0 * .pi / Double(teeth))
            let angle4 = angle1 + (1.5 * .pi / Double(teeth))
            
            let p1 = CGPoint(
                x: center.x + CGFloat(cos(angle1)) * (outerRadius - toothDepth),
                y: center.y + CGFloat(sin(angle1)) * (outerRadius - toothDepth)
            )
            let p2 = CGPoint(
                x: center.x + CGFloat(cos(angle2)) * outerRadius,
                y: center.y + CGFloat(sin(angle2)) * outerRadius
            )
            let p3 = CGPoint(
                x: center.x + CGFloat(cos(angle3)) * outerRadius,
                y: center.y + CGFloat(sin(angle3)) * outerRadius
            )
            let p4 = CGPoint(
                x: center.x + CGFloat(cos(angle4)) * (outerRadius - toothDepth),
                y: center.y + CGFloat(sin(angle4)) * (outerRadius - toothDepth)
            )
            
            if i == 0 {
                path.move(to: p1)
            } else {
                path.addLine(to: p1)
            }
            path.addLine(to: p2)
            path.addLine(to: p3)
            path.addLine(to: p4)
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Card Style Modifier
struct SASCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.sasCardBg)
            .cornerRadius(12)
    }
}

extension View {
    func sasCardStyle() -> some View {
        modifier(SASCardStyle())
    }
}

// MARK: - Button Styles
struct SASPrimaryButtonStyle: ButtonStyle {
    var color: Color = .sasOrange
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .foregroundColor(.white)
            .cornerRadius(8)
            .font(.system(size: 14, weight: .semibold))
    }
}

struct SASSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.sasCardBg)
            .foregroundColor(.sasTextPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sasBorder, lineWidth: 1)
            )
            .font(.system(size: 14, weight: .medium))
    }
}
