import SwiftUI
#if canImport(MarkdownUI)
import MarkdownUI
#endif

struct MarkdownText: View {
    let text: String

    var body: some View {
        #if canImport(MarkdownUI)
        Markdown(text)
            .markdownTheme(.chat)
            .textSelection(.enabled)
        #else
        Text(LocalizedStringKey(text))
            .textSelection(.enabled)
        #endif
    }
}

#if canImport(MarkdownUI)
extension Theme {
    /// A compact theme sized for chat bubbles.
    static let chat = Theme.basic
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color(.tertiarySystemFill))
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 8, bottom: 4)
                .markdownTextStyle { FontWeight(.bold); FontSize(.em(1.3)) }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 8, bottom: 4)
                .markdownTextStyle { FontWeight(.bold); FontSize(.em(1.15)) }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 6, bottom: 2)
                .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.05)) }
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle { FontFamilyVariant(.monospaced); FontSize(.em(0.85)) }
                    .padding(10)
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(.rect(cornerRadius: 8))
            .markdownMargin(top: 4, bottom: 8)
        }
}
#endif

#Preview {
    ScrollView {
        MarkdownText(text: """
        ## Ethanol
        Ethanol (**C₂H₆O**) is a *primary alcohol*.

        | Property | Value |
        |---|---|
        | Boiling point | 78.29 °C |
        | Melting point | −114.1 °C |

        - Flammable
        - Miscible with water

        ```
        CH3CH2OH
        ```
        > Source: Wikidata Q153
        """)
        .padding()
    }
}
