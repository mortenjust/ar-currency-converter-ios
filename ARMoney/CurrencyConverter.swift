//
//  CurrencyConverter.swift
//  ARKitImageRecognition
//
//  Created by Morten Just Petersen on 6/18/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit


struct CurrencyPrice {
    var currency : String;
    var foreignAmount : Double
    var amount : Double;
    var formattedAmount : String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.currencyGroupingSeparator = " "
        f.alwaysShowsDecimalSeparator = false
        return f.string(for: amount)!
    }
    var country : String
    var friendlyCurrency : String
}


class CurrencyConverter: NSObject {

    func convert(fromImageName i : String, targetCurrency:String) -> CurrencyPrice {
        let p = price(fromImageName: i)
        let c = convertToUSD(currencyPrice: p)
        return c
    }
    
    // --
    
    func format(amount : Double, currency : String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.currencyGroupingSeparator = " "
        f.alwaysShowsDecimalSeparator = false
        return f.string(for: amount)!
    }

    func price(fromImageName i : String) -> CurrencyPrice {
        let s = i.split(separator: "-") // e.g. CHF-20-A
        let cp = CurrencyPrice(
            currency: "\(s[0])",
            foreignAmount: Double(s[1])!,
            amount: Double(s[1])!,
            country: (ratesToUSD["\(s[0])"]?.country)!,
            friendlyCurrency: (ratesToUSD["\(s[0])"]?.friendlyCurrency)!)
        return cp
    }
    
    func convertToUSD(currencyPrice p : CurrencyPrice) -> CurrencyPrice {
        let calc = ratesToUSD[p.currency]!
        return CurrencyPrice(
            currency: "USD",
            foreignAmount: p.amount,
            amount: calc.rate * p.amount,
            country: calc.country,
            friendlyCurrency: calc.friendlyCurrency)
    }
    
    
    let ratesToUSD = [
        "DKK" : (rate: 0.16, country: "Denmark", friendlyCurrency:"Danish Kroner"),
        "CHF" : (rate:1, country: "Switzerland", friendlyCurrency:"Swiss Francs"),
        "EUR" : (rate: 1.20, country: "EU", friendlyCurrency:"Euros"),
        "GBP" : (rate: 1.36, country: "United Kingdom", friendlyCurrency:"British Pounds"),
        "CAD" : (rate:0.78, country: "Canada", friendlyCurrency:"Canadian Dollars"),
        "MXN" : (rate: 0.05, country: "Mexico", friendlyCurrency:"Mexican Pesos"),
        "USD" : (rate: 1, country: "United States", friendlyCurrency:"US Dollars"),
        "SGD" : (rate:0.75, country: "Singapore", friendlyCurrency:"Singapore Dollars")
    ]
    
}


