import Carbon.HIToolbox
import Foundation

enum KeyboardLayout {
    private static let qwertyFallbackLetters: [Int64: Character] = [
        0: "a",
        1: "s",
        2: "d",
        3: "f",
        4: "h",
        5: "g",
        6: "z",
        7: "x",
        8: "c",
        9: "v",
        11: "b",
        12: "q",
        13: "w",
        14: "e",
        15: "r",
        16: "y",
        17: "t",
        31: "o",
        32: "u",
        34: "i",
        35: "p",
        37: "l",
        38: "j",
        40: "k",
        45: "n",
        46: "m"
    ]

    static func letter(for keyCode: Int64) -> Character? {
        translatedLatinLetter(for: keyCode) ?? qwertyFallbackLetters[keyCode]
    }

    private static func translatedLatinLetter(for keyCode: Int64) -> Character? {
        guard
            let layoutData = currentKeyboardLayoutData(),
            let keyboardLayout = CFDataGetBytePtr(layoutData)
        else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = keyboardLayout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayoutPointer in
            UCKeyTranslate(
                keyboardLayoutPointer,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else {
            return nil
        }

        let translated = String(utf16CodeUnits: chars, count: length).lowercased()
        guard let letter = translated.first, letter.isASCII, letter.isLetter else {
            return nil
        }

        return letter
    }

    private static func currentKeyboardLayoutData() -> CFData? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }

        let key = "TISPropertyUnicodeKeyLayoutData" as CFString
        guard let property = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
    }
}
