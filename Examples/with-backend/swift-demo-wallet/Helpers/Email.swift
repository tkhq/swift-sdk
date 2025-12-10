import Foundation

func isValidEmail(_ email: String) -> Bool {
    let regex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    return email.range(of: regex, options: .regularExpression) != nil
}
