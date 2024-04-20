//
//  Bundle.swift
//  Shared
//
//  Created by Saagar Jha on 1/26/24.
//

import Foundation

extension Bundle {
    var name: String {
        Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    }

	var bounjourServiceName: String {
		(Bundle.main.infoDictionary!["BONJOUR_SERVICE"] as! String).lowercased()
	}

	var version: Int {
		13
	}
}
