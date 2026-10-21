import 'models.dart';

/// Daily prompts, shipped with the app. One per day, same for everyone on a
/// given date, chosen on device.
const _prompts = <DailyPrompt>[
  DailyPrompt(text: 'Draw your keys without lifting the pen.', minutes: 3),
  DailyPrompt(text: 'Your left hand, holding something.', minutes: 5),
  DailyPrompt(text: 'The view from where you’re sitting, in ten lines.', minutes: 3),
  DailyPrompt(text: 'A mug, using only one ink.', minutes: 3),
  DailyPrompt(text: 'Someone nearby, in under two minutes.', minutes: 2),
  DailyPrompt(text: 'Your shoes, from above.', minutes: 5),
  DailyPrompt(text: 'A plant, leaf by leaf.', minutes: 10),
  DailyPrompt(text: 'Three shadows in the room.', minutes: 5),
  DailyPrompt(text: 'The last thing you ate.', minutes: 3),
  DailyPrompt(text: 'A doorway, with something half‑visible behind it.', minutes: 5),
  DailyPrompt(text: 'Your bag, emptied out.', minutes: 10),
  DailyPrompt(text: 'A chair, drawn with your other hand.', minutes: 3),
  DailyPrompt(text: 'The sky right now, using only shapes.', minutes: 2),
  DailyPrompt(text: 'A street sign or label, letters and all.', minutes: 5),
  DailyPrompt(text: 'A crumpled piece of paper.', minutes: 5),
  DailyPrompt(text: 'Your face in a reflection, in one continuous line.', minutes: 3),
  DailyPrompt(text: 'Everything on your desk, smallest first.', minutes: 10),
  DailyPrompt(text: 'A fruit, then the same fruit cut open.', minutes: 5),
  DailyPrompt(text: 'A window with the light coming through.', minutes: 5),
  DailyPrompt(text: 'A tool you used today.', minutes: 3),
  DailyPrompt(text: 'The inside of a cupboard.', minutes: 5),
  DailyPrompt(text: 'A pattern you can see from here.', minutes: 3),
  DailyPrompt(text: 'Your hand, five different ways.', minutes: 10),
  DailyPrompt(text: 'A building, using only straight lines.', minutes: 5),
  DailyPrompt(text: 'An animal from memory, then fix it from a photo.', minutes: 10),
  DailyPrompt(text: 'A bottle and what’s behind it, seen through the glass.', minutes: 5),
  DailyPrompt(text: 'Something tiny, drawn huge.', minutes: 3),
  DailyPrompt(text: 'Your route home, as a map.', minutes: 5),
  DailyPrompt(text: 'A pile of clothes.', minutes: 5),
  DailyPrompt(text: 'Two objects that overprint: one blue, one orange.', minutes: 3),
];

/// Today's prompt (rotates daily through the list).
DailyPrompt promptFor(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return _prompts[day % _prompts.length];
}
