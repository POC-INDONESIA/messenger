// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/message_content.dart';
import 'package:fluffychat/utils/markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
// ignore: implementation_imports
import 'package:matrix/src/models/timeline_chunk.dart';

import 'utils/test_client.dart';

Iterable<TextSpan> _allTextSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _allTextSpans(child);
  }
}

bool _hasStyledText(InlineSpan span, String text, TextStyle style) =>
    _allTextSpans(span).any(
      (child) =>
          child.toPlainText() == text &&
          (style.fontWeight == null ||
              child.style?.fontWeight == style.fontWeight) &&
          (style.fontStyle == null ||
              child.style?.fontStyle == style.fontStyle),
    );

void main() {
  group('markdownToHtml', () {
    test('converts inline formatting', () {
      expect(
        markdownToHtml('**bold** and *italic* and ~~strike~~'),
        '<strong>bold</strong> and <em>italic</em> and <del>strike</del>',
      );
    });

    test('keeps line breaks', () {
      expect(markdownToHtml('line one\nline two'), 'line one<br />\nline two');
    });

    test('converts lists and headings', () {
      expect(
        markdownToHtml('# Title\n\n- one\n- two'),
        '<h1>Title</h1>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>',
      );
    });

    test('escapes raw html', () {
      expect(markdownToHtml('<b>not bold</b>'), '&lt;b&gt;not bold&lt;/b&gt;');
      expect(markdownToHtml('`<b>`'), '<code>&lt;b&gt;</code>');
    });

    test('keeps plain text untouched', () {
      expect(markdownToHtml('hello world'), 'hello world');
    });
  });

  group('sending', () {
    test('sends a formatted body for markdown messages', () async {
      final client = await prepareTestClient();
      final room = Room(id: '!1234:example.com', client: client);

      await room.sendTextEvent('**bold**', txid: '1234');

      final content =
          jsonDecode(
                FakeMatrixApi
                        .calledEndpoints['/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/1234']!
                        .last
                    as String,
              )
              as Map<String, dynamic>;
      expect(content['format'], 'org.matrix.custom.html');
      expect(content['formatted_body'], contains('<strong>bold</strong>'));
    });
  });

  group('MessageContent', () {
    late Client client;

    setUpAll(() async {
      client = await prepareTestClient();
    });

    testWidgets('renders markdown of plain text messages', (tester) async {
      final room = client.rooms.first;
      final event = Event(
        eventId: r'$markdown',
        senderId: client.userID!,
        originServerTs: DateTime.now(),
        type: EventTypes.Message,
        content: {'msgtype': 'm.text', 'body': '**bold** and *italic*'},
        room: room,
      );
      final timeline = Timeline(
        room: room,
        chunk: TimelineChunk(events: [event]),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: MessageContent(
              event,
              timeline: timeline,
              textColor: Colors.black,
              linkColor: Colors.blue,
              borderRadius: BorderRadius.zero,
              selected: false,
              bigEmojis: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(MessageContent),
              matching: find.byType(Text),
            )
            .first,
      );
      final span = text.textSpan!;
      expect(span.toPlainText(), 'bold and italic');
      expect(
        _hasStyledText(
          span,
          'bold',
          const TextStyle(fontWeight: FontWeight.bold),
        ),
        isTrue,
      );
      expect(
        _hasStyledText(
          span,
          'italic',
          const TextStyle(fontStyle: FontStyle.italic),
        ),
        isTrue,
      );
    });
  });
}
