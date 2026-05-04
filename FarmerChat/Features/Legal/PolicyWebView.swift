//
//  PolicyWebView.swift
//  FarmerChat
//
//  In-app WebView for Terms/Privacy/FAQ URLs or HTML content (WKWebView).
//

import SwiftUI
import WebKit

struct PolicyWebView: View {
    let url: URL?
    let title: String
    var htmlContent: String?
    var onDismiss: (() -> Void)?

    init(url: URL, title: String, htmlContent: String? = nil, onDismiss: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.htmlContent = htmlContent
        self.onDismiss = onDismiss
    }

    /// Load HTML string (e.g. FAQ answer from API) instead of a URL.
    init(htmlContent: String, title: String, onDismiss: (() -> Void)? = nil) {
        self.url = nil
        self.title = title
        self.htmlContent = htmlContent
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Group {
                if let url = url, htmlContent == nil {
                    WebViewRepresentable(url: url)
                } else if let html = htmlContent {
                    WebViewRepresentable(htmlString: html)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: toolbarDonePlacement) {
                    Button("Done") { onDismiss?() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }

    private var toolbarDonePlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .confirmationAction
        #endif
    }
}

#if os(iOS)
struct WebViewRepresentable: UIViewRepresentable {
    var url: URL?
    var htmlString: String?

    init(url: URL) {
        self.url = url
        self.htmlString = nil
    }

    init(htmlString: String) {
        self.url = nil
        self.htmlString = htmlString
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        if let url = url {
            webView.load(URLRequest(url: url))
        } else if let html = htmlString {
            webView.loadHTMLString(wrapInPage(html), baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url == nil, let html = htmlString, context.coordinator.lastHtml != html {
            context.coordinator.lastHtml = html
            uiView.loadHTMLString(wrapInPage(html), baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {
        var lastHtml: String?
    }

    private func wrapInPage(_ body: String) -> String {
        if body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<!doctype") ||
            body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<html") {
            return body
        }
        return """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>\
        <body style="font-family: -apple-system, sans-serif; padding: 16px;">\(body)</body></html>
        """
    }
}
#else
struct WebViewRepresentable: View {
    var url: URL?
    var htmlString: String?

    init(url: URL) { self.url = url; self.htmlString = nil }
    init(htmlString: String) { self.url = nil; self.htmlString = htmlString }

    var body: some View {
        if let url = url {
            Link("Open in browser", destination: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(htmlString ?? "")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
