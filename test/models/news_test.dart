// FLUTTER / DART / THIRD-PARTIES
// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// MODELS
import 'package:notredame/core/models/news.dart';
import 'package:notredame/core/models/tags.dart';

void main() {
  group('News class tests', () {
    test('News.fromJson() should parse JSON correctly', () {
      final json = {
        'id': 1,
        'title': 'Test Title',
        'description': 'Test Description',
        'author': 'Test Author',
        'activity': 'Test Activity',
        'avatar': 'https://example.com/avatar.jpg',
        'image': 'https://example.com/image.jpg',
        'tags': [
          {'text': 'Tag 1', 'color': Colors.blue.value},
          {'text': 'Tag 2', 'color': Colors.red.value},
        ],
        'publishedDate': '2022-01-01T12:00:00Z',
        'eventDate': '2022-01-01T12:00:00Z',
      };

      final news = News.fromJson(json);

      expect(news.id, equals(1));
      expect(news.title, equals('Test Title'));
      expect(news.description, equals('Test Description'));
      expect(news.author, equals('Test Author'));
      expect(news.activity, equals('Test Activity'));
      expect(news.avatar, equals('https://example.com/avatar.jpg'));
      expect(news.image, equals('https://example.com/image.jpg'));
      expect(news.tags.length, equals(2));
      expect(news.tags[0], equals('Tag 1'));
      expect(news.tags[1], equals('Tag 2'));
      expect(news.publishedDate, equals(DateTime.parse('2022-01-01T12:00:00Z')));
      expect(news.eventDate, equals(DateTime.parse('2022-01-01T12:00:00Z')));
    });

    test('toJson() should convert News to JSON correctly', () {
      final news = News(
        id: 1,
        title: 'Test Title',
        description: 'Test Description',
        author: 'Test Author',
        avatar: 'https://example.com/avatar.jpg',
        activity: 'Test Activity',
        image: 'https://example.com/image.jpg',
        tags: [
          'Tag 1',
          'Tag 2'
        ],
        publishedDate: DateTime.parse('2022-01-01T12:00:00Z'),
        eventDate: DateTime.parse('2022-01-01T12:00:00Z'),
      );

      final json = news.toJson();

      expect(json['id'], equals(1));
      expect(json['title'], equals('Test Title'));
      expect(json['description'], equals('Test Description'));
      expect(json['author'], equals('Test Author'));
      expect(json['avatar'], equals('https://example.com/avatar.jpg'));
      expect(json['activity'], equals('Test Activity'));
      expect(json['image'], equals('https://example.com/image.jpg'));
      expect(json['tags'], hasLength(2));
      expect(json['tags'][0]['text'], equals('Tag 1'));
      expect(json['tags'][0]['color'], equals(Colors.blue[500].value));
      expect(json['tags'][1]['text'], equals('Tag 2'));
      expect(json['tags'][1]['color'], equals(Colors.red[500].value));
      expect(json['publishedDate'], equals('2022-01-01 12:00:00.000Z'));
      expect(json['eventDate'], equals('2022-01-01 12:00:00.000Z'));
    });
  });

  group('Tag class tests', () {
    test('Tag.fromJson() should parse JSON correctly', () {
      final json = {
        'text': 'Test Tag',
        'color': Colors.blue[500].value,
      };

      final tag = Tag.fromJson(json);

      expect(tag.text, equals('Test Tag'));
      expect(tag.color, equals(Colors.blue[500]));
    });

    test('toJson() should convert Tag to JSON correctly', () {
      final tag = Tag(text: 'Test Tag', color: Colors.blue[500]);

      final json = tag.toJson();

      expect(json['text'], equals('Test Tag'));
      expect(json['color'], equals(Colors.blue[500].value));
    });
  });
}
