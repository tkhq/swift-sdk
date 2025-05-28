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

func formatToE164(_ number: String, region: String) -> String? {
    guard let parsed = try? phoneKit.parse(number, withRegion: region) else {
        return nil
    }
    return phoneKit.format(parsed, toType: .e164)
}

func parsePhone(_ e164Number: String) -> (regionCode: String, nationalNumber: String)? {
    do {
        let parsed = try phoneKit.parse(e164Number)
        let region = phoneKit.getRegionCode(of: parsed)!
        let nationalNumber = String(parsed.nationalNumber)
        return (region, nationalNumber)
    } catch {
        return nil
    }
}
