import Foundation

/**
 * Rule converter
 */
class RuleConverter {
    private let COMMENT = "!";
    
    private let UBO_SCRIPTLET_MASK_REG = "##script\\:inject|#@?#\\s*\\+js";
    private let UBO_SCRIPTLET_MASK_1 = "##+js";
    private let UBO_SCRIPTLET_MASK_2 = "##script:inject";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_1 = "#@#+js";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_2 = "#@#script:inject";
    private let UBO_SCRIPT_TAG_MASK = "##^script";
    /**
     * AdBlock Plus snippet rule mask
     */
    private let ABP_SCRIPTLET_MASK = "#$#";
    private let ABP_SCRIPTLET_EXCEPTION_MASK = "#@$#";
    
    /**
     * AdGuard CSS rule mask
     */
    private let ADG_CSS_MASK_REG = "#@?\\$#.+?\\s*\\{.*\\}\\s*$";
    
    /**
     * AdGuard scriptlet mask
     */
    private let ADGUARD_SCRIPTLET_MASK = "${domains}#%#//scriptlet(${args})";

    /**
     * AdGuard scriptlet exception mask
     */
    private let ADGUARD_SCRIPTLET_EXCEPTION_MASK = "${domains}#@%#//scriptlet(${args})";
    
    /**
     * Converts text to AG supported rule format
     */
    func convertRule(rule: String) -> [String] {
        if (isComment(rule: rule)) {
            return [rule];
        }
        
        if (isUboScriptletRule(rule: rule)) {
            return [convertUboScriptletRule(rule: rule)];
        }
        
        if (isAbpSnippetRule(rule: rule)) {
            return convertAbpSnippetRule(rule: rule);
        }
//
        // TODO: Convert other types
//        const uboScriptRule = convertUboScriptTagRule(rule);
//        if (uboScriptRule) {
//            return uboScriptRule;
//        }
//
//        const uboCssStyleRule = convertUboCssStyleRule(rule);
//        if (uboCssStyleRule) {
//            return uboCssStyleRule;
//        }

        // Convert abp redirect rule
        let abpRedirectRule = convertAbpRedirectRule(rule: rule);
        if (abpRedirectRule != nil) {
            return [abpRedirectRule!];
        }

//        // Convert options
//        const ruleWithConvertedOptions = convertOptions(rule);
//        if (ruleWithConvertedOptions) {
//            return ruleWithConvertedOptions;
//        }
//
//        return rule;
        
        return [rule];
    }
    
    private func isComment(rule: String) -> Bool {
        return rule.hasPrefix(COMMENT);
    }
    
    private func isUboScriptletRule(rule: String) -> Bool {
        return (rule.contains(UBO_SCRIPTLET_MASK_1) || rule.contains(UBO_SCRIPTLET_MASK_2) || rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_1) || rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_2)) && rule.isMatch(regex: UBO_SCRIPTLET_MASK_REG);
    }
    
    private func convertUboScriptletRule(rule: String) -> String {
        let mask = rule.matches(regex: UBO_SCRIPTLET_MASK_REG)[0];
        let domains = rule.subString(from: 0, toSubstring: mask);

        let template: String;
        if (mask.contains("@")) {
            template = ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        } else {
            template = ADGUARD_SCRIPTLET_MASK;
        }

        let clean = getStringInBraces(str: rule);
        let parsedArgs = clean.components(separatedBy: ", ");
          
        var args = [String]();
        for i in (0 ..< parsedArgs.count) {
            var arg = parsedArgs[i];
            if i == 0 {
                arg = "ubo-" + arg;
            }
            
            args.append(wrapInDoubleQuotes(str: arg));
        }
        
        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains!, args: argsString);
    }
    
    private func isAbpSnippetRule(rule: String) -> Bool {
        return (
            rule.contains(ABP_SCRIPTLET_MASK) ||
            rule.contains(ABP_SCRIPTLET_EXCEPTION_MASK)) &&
            !rule.isMatch(regex: ADG_CSS_MASK_REG);
    }
    
    /**
     * Convert string of ABP scriptlet rule to AdGuard scriptlet rule
     */
    private func convertAbpSnippetRule(rule: String) -> [String] {
        let mask = rule.contains(ABP_SCRIPTLET_MASK)
            ? ABP_SCRIPTLET_MASK
            : ABP_SCRIPTLET_EXCEPTION_MASK;
        
        let template = mask == ABP_SCRIPTLET_MASK
            ? ADGUARD_SCRIPTLET_MASK
            : ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        
        let domains = rule.subString(from: 0, toSubstring: mask);
        let maskIndex = rule.indexOf(target: mask);
        let args = rule.subString(startIndex: maskIndex + mask.count);
        
        let splitted = args.components(separatedBy: "; ");
        
        var result = [String]();
        
        for s in splitted {
            
            var sentences = [String]();
            let sen = getSentences(str: s);
            for part in sen {
                if (part != "") {
                    sentences.append(part);
                }
            }
            
            var wrapped = [String]();
            for (index, sentence) in sentences.enumerated() {
                let w = index == 0 ? "abp-" + sentence : sentence;
                wrapped.append(wrapInDoubleQuotes(str: w));
            }
            
            let converted = replacePlaceholders(str: template, domains: domains!, args: wrapped.joined(separator: ", "))
            result.append(converted);
        }
        
        return result;
    }
    
    /**
     * Converts abp rule into ag rule
     * e.g.
     * from:    "||example.org^$rewrite=abp-resource:blank-mp3"
     * to:      "||example.org^$redirect:blank-mp3"
     */
    private func convertAbpRedirectRule(rule: String) -> String? {
        let ABP_REDIRECT_KEYWORD = "rewrite=abp-resource:";
        let AG_REDIRECT_KEYWORD = "redirect=";
        if (!rule.contains(ABP_REDIRECT_KEYWORD)) {
            return nil;
        }
        return rule.replace(target: ABP_REDIRECT_KEYWORD, withString: AG_REDIRECT_KEYWORD);
    }

    // Helpers
    
    /**
    * Return array of strings separated by space which not in quotes
    */
    private func getSentences(str: String) -> [String] {
        let reg = #"'.*?'|".*?"|\S+"#;
        return str.matches(regex: reg);
    }

    private func getStringInBraces(str: String) -> String {
        let firstIndex = str.indexOf(target: "(");
        let lastIndex = str.lastIndexOf(target: ")");
        return str.subString(startIndex: firstIndex + 1, length: lastIndex - firstIndex - 1);
    }
    
    private func wrapInDoubleQuotes(str: String) -> String {
        var modified = str;
        if str.hasPrefix("\'") && str.hasSuffix("\'") {
            modified = str.subString(startIndex: 1, length: str.count - 2);
            modified = modified.replace(target: "\"", withString: "\\\"");
        } else if str.hasPrefix("\"") && str.hasSuffix("\"") {
            modified = str.subString(startIndex: 1, length: str.count - 1);
            modified = modified.replace(target: "'", withString: "\'");
        }
        
        return "\"" + modified + "\"";
    }
    
    private func replacePlaceholders(str: String, domains: String, args: String) -> String {
        var result = str.replace(target: "${domains}", withString: domains);
        result = result.replace(target: "${args}", withString: args);
        
        return result;
    }
}
