import UIKit
import Foundation

var str = "Hello, playground"

var s = "CHF-20-A"
var s1 = s.split(separator:"-")
print(s1)


func formatAmount(amount : Float) -> String {

    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "DKK"
    f.currencyGroupingSeparator = " "
    f.alwaysShowsDecimalSeparator = false
    

    let a : Float = 1553.0

    return f.string(for: a)!
}

print(formatAmount(amount: 39325.00))
