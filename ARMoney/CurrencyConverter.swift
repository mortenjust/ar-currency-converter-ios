//
//  CurrencyConverter.swift
//  ARKitImageRecognition
//
//  Created by Morten Just Petersen on 6/18/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit



class CurrencyConverter: NSObject {
    struct CurrencyPrice {
        var currency : String;
        var amount : Double;
        var formattedAmount : String {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currency
            f.currencyGroupingSeparator = " "
            f.alwaysShowsDecimalSeparator = false
            return f.string(for: amount)!
        }
    }
    
    
    func convert(fromImageName i : String, targetCurrency:String) -> CurrencyPrice {
        let p = price(fromImageName: i)
        let c = convertToUSD(currencyPrice: p)
        return c
    }

    func price(fromImageName i : String) -> CurrencyPrice {
        let s = i.split(separator: "-") // e.g. CHF-20-A
        return CurrencyPrice(currency: "\(s[0])", amount: Double(s[1])!) // TODO protect against bad imagenames
    }
    
    func convertToUSD(currencyPrice p : CurrencyPrice) -> CurrencyPrice {
        return CurrencyPrice(currency: "USD", amount: ratesToUSD[p.currency]! * p.amount)
    }
    
    
    
    let ratesToUSD = [
        "DKK" : 0.16,
        "CHF" : 1,
        "EUR" : 1.20,
        "GBP" : 1.36,
        "CAD" : 0.78,
        "MXN" : 0.05,
        "SGD" : 0.75
    ]
    
}


