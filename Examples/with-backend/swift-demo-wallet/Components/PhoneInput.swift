import PhoneNumberKit
import SwiftUI

let unsupportedCountryCodes: Set<String> = [
    "AF", "IQ", "SY", "SD", "IR", "KP", "CU", "RW", "VA",
]

let allowedCountryCodes: [String] = Locale.Region.isoRegions
    .map(\.identifier)
    .filter {
        !unsupportedCountryCodes.contains($0) &&

            // this excludes non-country regions
            phoneKit.countryCode(for: $0) != nil &&

            // this excludes "world"
            phoneKit.countryCode(for: $0) != 979
    }
    .sorted()

func flag(for countryCode: String) -> String {
    countryCode
        .unicodeScalars
        .compactMap { UnicodeScalar(127_397 + $0.value) }
        .map(String.init)
        .joined()
}

func callingCode(for region: String) -> String {
    guard let code = phoneKit.countryCode(for: region) else { return "" }
    return String(code)
}

struct PhoneInputView: View {
    @Binding var selectedCountry: String
    @Binding var phoneNumber: String
    @State private var showCountryPicker = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(flag(for: selectedCountry))
                        .font(.system(size: 20))

                    Text("+\(callingCode(for: selectedCountry))")
                        .font(.system(size: 16))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .cornerRadius(8)
            }

            TextField("Phone number", text: $phoneNumber)
                .keyboardType(.numberPad)
                .font(.system(size: 16))
        }
        .padding()
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selected: $selectedCountry)
        }
    }
}

struct CountryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selected: String
    @State private var searchText = ""

    var filteredCountries: [String] {
        allowedCountryCodes.filter {
            searchText.isEmpty || Locale.current.localizedString(forRegionCode: $0)?.lowercased().contains(searchText.lowercased()) == true
        }
    }

    var body: some View {
        NavigationView {
            List(filteredCountries, id: \.self) { code in
                Button {
                    selected = code
                    dismiss()
                } label: {
                    HStack {
                        Text("\(flag(for: code)) \(Locale.current.localizedString(forRegionCode: code) ?? code)")
                            .foregroundColor(.black)

                        Spacer()

                        if code == selected {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text("Select Country")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer(minLength: 12)
                    }
                }
            }
            .searchable(text: $searchText)
        }
    }
}
