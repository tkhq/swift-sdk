import Foundation
import PhoneNumberKit

let phoneKit = PhoneNumberUtility()

func isValidEmail(_ email: String) -> Bool {
    let regex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    return email.range(of: regex, options: .regularExpression) != nil
}

func isValidPhone(_ number: String, region: String) -> Bool {
    (try? phoneKit.parse(number, withRegion: region)) != nil
}

