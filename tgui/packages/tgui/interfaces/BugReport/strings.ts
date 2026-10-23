// THIS IS AN APHELION UI FILE

/**
 * Every word the report window shows, keyed by its row in the design's strings sheet. Plurals that the sheet
 * writes as "many / one" are two keys here, the one-form ending in .one
 */
export const STRINGS = {
  'win.title': 'Report a bug',
  'step.of': 'Step {n} of 4 · {name}',
  'step.1': 'Report title',
  'step.2': 'Picture',
  'step.3': 'Steps',
  'step.4': 'Review report',
  'step.strip': 'Steps of the report',
  'step.done.aria': 'Go back to step {n}, {name}',
  'btn.next': 'Next',
  'btn.back': 'Back',

  'p1.heading': 'Report title',
  'p1.title.hint': 'A brief overview of the issue',
  count: '{n} of {max}',

  'p2.heading': 'Add a picture',
  'p2.intro': 'Optional, but helpful if this is a visual bug.',
  'p2.view': 'In-game capture',
  'p2.view.hint': "A picture of what's around you in the game",
  'p2.windows': 'Your windows',
  'p2.windows.hint': "You check it in that window before it's added.",
  'p2.windows.none':
    'No other windows are open. Open the one with the problem, then look again.',
  'p2.windows.again': 'Look again',
  'p2.file': 'Your own screenshot',
  'p2.file.hint': 'A PNG, JPEG, WebP or GIF, up to 10 MB',
  'p2.busy': 'Wait for this one to finish',
  'p2.wait': 'Wait for the other picture to finish',
  'p2.left': 'You can upload {n} more of your own screenshots this hour.',
  'p2.left.one': 'You can upload 1 more of your own screenshots this hour.',
  'p2.max':
    "That's {max} pictures, the most a report takes. Remove one to add another.",
  'p2.more': 'You can add {n} more pictures to this report.',
  'p2.more.one': 'You can add 1 more picture to this report.',

  'shots.title': 'Attached screenshots',
  'shots.none': 'Nothing attached yet.',
  'shot.view': 'In-game capture · {time}',
  'shot.window': '{window} · {time}',
  'shot.file': 'Your own screenshot · {time}',
  'shot.rendering': 'Taking the in-game capture…',
  'shot.waiting': 'Check it in {window}, then add it.',
  'shot.uploading': 'Adding your picture…',
  'shot.checking': 'Checking the picture…',
  'shot.loading': 'Loading the picture…',
  'shot.failed':
    "This picture can't be used. Pick a PNG, JPEG, WebP or GIF under 10 MB, or remove it.",
  'shot.unconfirmed':
    "Couldn't confirm the picture was added. Try again, or pick it again.",
  'shot.previewFailed': "The preview didn't load.",
  'btn.loadAgain': 'Load it again',
  'shot.alt.view': 'In-game capture of your view',
  'shot.alt.window': 'Capture of the {window} window',
  'shot.alt.file': 'Your own screenshot',
  'shot.public': 'Show it on the public GitHub issue',
  'shot.public.hint':
    "It may show other players' names or chat. Only staff see it unless you tick this.",
  'shot.public.locked': 'Open the picture first, to check it.',
  'shot.gone': "That window isn't open any more. Pick another one.",
  'btn.retake': 'Retake',
  'btn.pickAnother': 'Pick another',
  'btn.remove': 'Remove',
  'btn.remove.aria': 'Remove {caption}',
  'view.failed':
    "The in-game capture didn't work. Try again, or add your own screenshot.",
  'view.nothing': "There's nothing to see from where you are.",
  'btn.tryCapture': 'Try again',

  'p3.heading': 'How do you make it happen again?',
  'p3.steps': 'Steps',
  'p3.steps.hint':
    'What you did, in order, one thing per step. Enter adds the next one.',
  'p3.step': 'Step {n}',
  'btn.addStep': 'Add a step',
  'btn.removeStep.aria': 'Remove step {n}',
  'p3.expected': 'What should have happened?',
  'p3.expected.hint': 'What you expected instead',
  'kind.legend': "What's it about?",
  'impact.legend': 'How much does it get in the way?',
  optional: '(optional)',
  'p3.vague':
    '"{text}" won\'t help anyone find it. What did you do just before it broke?',
  'btn.addSteps': 'Add steps',
  'btn.keepIt': 'Keep it',

  'p4.heading': 'Review report',
  'p4.row.title': 'Title',
  'p4.row.steps': 'Steps',
  'p4.row.expected': 'What should have happened',
  'p4.row.kind': "What it's about",
  'p4.row.impact': 'How much it gets in the way',
  'p4.row.pictures': 'Pictures',
  'p4.skipped': 'Not answered',
  'p4.pictures.none': 'None',
  'p4.pictures.private': '{n} attached, only staff see them',
  'p4.pictures.private.one': '1 attached, only staff see it',
  'p4.pictures.public': '{n} attached, {k} on the public issue',
  'btn.change': 'Change',
  'btn.change.aria': 'Change {label}',
  'p4.public':
    'Your report goes up anonymously on GitHub, where anyone can read it.',
  'btn.send': 'Send report',
  'btn.sending': 'Sending…',
  'btn.sendAgain': 'Send it again',

  'err.summary': 'Fill these in first',
  'err.prefix': 'Fix this:',
  'err.title': 'Give it a title.',
  'err.steps': 'Add at least one step.',
  'err.expected': 'Say what should have happened.',
  'err.tooLong': "That's {n} characters too long.",
  'err.tooLong.one': "That's 1 character too long.",
  'err.pictureBusy': 'Wait for the picture to finish, or remove it.',

  'st.sending': 'Sending your report…',
  'st.checking': 'Checking your report…',
  'st.checking.detail':
    "This usually takes a few seconds. Closing the window won't lose it.",
  'st.back.title': 'Your report needs a little more',
  'st.back.text':
    'The automatic check sent it back. Fix the parts marked below, then send it again.',
  'st.back.item': '{label}: {message}',
  'st.back.quote': 'You wrote: "{quote}"',
  'st.limit.reports':
    "You've sent {reports} reports this hour, which is the limit. You can send this one at {clock}, in about {wait}. It's kept here, so you can close this window.",
  'st.limit.sends':
    "You've tried to send {sends} times this hour. You can try again at {clock}, in about {wait}. Your report is kept.",
  'st.limit.pictures':
    "You've uploaded {uploads} of your own screenshots this hour, which is the limit. Captures still work.",
  'time.wait': '{n} minutes',
  'time.wait.one': 'a minute',
  'time.wait.less': 'under a minute',
  'st.offline.title': "Couldn't reach the report server",
  'st.offline.text': 'Your report is kept. Try again in a minute.',
  'st.offline.again':
    "Still can't reach it. Try again in a few minutes. Your report is kept.",
  'btn.tryAgain': 'Try again',
  'st.lost':
    'Lost touch with the report server while it was checking. Your report is kept.',
  'st.off':
    "Bug reports aren't set up on this server right now. Your text is kept.",
  'st.done.title': 'Report sent',
  'st.done.issue': "Thanks. It's on GitHub as issue #{n}.",
  'st.done.soon':
    "Thanks. It's saved, and the GitHub link shows up here in a moment.",
  'st.done.waiting': 'Waiting for the GitHub link…',
  'st.done.queue':
    "Thanks. It's saved and waiting in line for GitHub, which can take a day or more. You don't need to send it again.",
  'st.done.retry':
    "Thanks. It's saved. GitHub didn't answer, so it tries again at {clock}.",
  'st.done.staff':
    "Thanks. It's saved, and staff will look at it before it goes on GitHub.",
  'btn.openIssue': 'Open it on GitHub',
  'st.done.browser': 'The GitHub link opens in your browser.',
  'btn.another': 'Report something else',
  'st.done.next': 'Find it again with Recent bug reports in the OOC tab.',
  'st.conflict':
    'This report was also changed somewhere else. Which version do you want to keep?',
  'btn.useSaved': 'Use the saved one',
  'btn.keepMine': 'Keep mine',
} as const;

export type StringId = keyof typeof STRINGS;

/** Returns a string with its {placeholders} filled in */
export function say(
  id: StringId,
  values?: Record<string, string | number>,
): string {
  const template: string = STRINGS[id];
  if (!values) return template;
  return template.replace(/\{(\w+)\}/g, (whole, key: string) =>
    key in values ? String(values[key]) : whole,
  );
}
