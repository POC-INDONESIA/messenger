// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:markdown/markdown.dart' as md;

/// GitHub flavored markdown without raw HTML, so that a plain text message can
/// never inject markup into the chat.
final _markdownExtensionSet = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  md.ExtensionSet.gitHubFlavored.inlineSyntaxes
      .where((syntax) => syntax is! md.InlineHtmlSyntax)
      .toList(),
);

const _blockHtmlTags = {
  'table',
  'pre',
  'ol',
  'ul',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'div',
};

/// Converts a plain text message body with markdown into the HTML subset which
/// is rendered by `HtmlMessage`.
///
/// Line breaks are kept, so that chat messages look the same with and without
/// markdown.
String markdownToHtml(String text) {
  if (text.trim().isEmpty) return '';

  var html = md
      .markdownToHtml(
        text,
        extensionSet: _markdownExtensionSet,
        encodeHtml: true,
      )
      .trim();

  html = html.replaceAllMapped(
    RegExp(r'<p>(.*?)</p>', dotAll: true),
    (match) => '<p>${match[1]!.replaceAll('\n', '<br />\n')}</p>',
  );
  html = html.replaceAll(RegExp(r'(?:\s*<br />)+\s*</p>'), '</p>');

  final singleParagraph =
      '<p>'.allMatches(html).length <= 1 &&
      !_blockHtmlTags.any((tag) => html.contains('</$tag>'));
  if (singleParagraph) {
    html = html.replaceFirstMapped(
      RegExp(r'^<p>(.*?)</p>$', dotAll: true),
      (match) => match[1]!,
    );
  }

  return html.replaceAll(RegExp(r'(?:\s*<br />)+$'), '').trim();
}
