import Foundation

/// Текст интерфейса на языке системы. Ключ — английский текст; переводы — в Resources/<язык>.lproj.
func L(_ english: String) -> String {
    Bundle.main.localizedString(forKey: english, value: english, table: nil)
}
