// THIS IS AN APHELION UI FILE
import { useEffect, useRef } from 'react';

export type StartupMessage = {
  text: string;
  warning: boolean;
};

type ProgressState = {
  previousTick: number;
  currentTime: number;
  completionTime: number;
  currentPosition: number;
  subStart: number;
  targetSubStart: number;
};

/**
 * Startup terminal + progress bar shown while the map is still loading
 * (SSticker.current_state == GAME_STATE_STARTUP).
 */
export function BootTerminal({
  messages,
  progressCurrent,
  progressTotal,
}: {
  messages: StartupMessage[];
  progressCurrent: number;
  progressTotal: number;
}) {
  const progressBarRef = useRef<HTMLDivElement>(null);
  const subProgressBarRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);

  const state = useRef<ProgressState>({
    previousTick: Date.now(),
    currentTime: progressCurrent,
    completionTime: progressTotal || 1,
    currentPosition: 0,
    subStart: 0,
    targetSubStart: 0,
  });

  useEffect(() => {
    state.current.currentTime = progressCurrent;
    state.current.completionTime = progressTotal || 1;
    state.current.targetSubStart = state.current.currentPosition;
  }, [progressCurrent, progressTotal]);

  useEffect(() => {
    let frameId: number;

    const renderFrame = () => {
      const progress = state.current;
      const tick = Date.now();
      const elapsedMs = tick - progress.previousTick;
      if (progress.currentTime < progress.completionTime) {
        progress.currentTime += elapsedMs / 100;
      }
      progress.previousTick = tick;

      progress.currentPosition = Math.min(
        Math.max(
          (progress.currentTime / progress.completionTime) * 100,
          progress.currentPosition,
        ),
        100,
      );

      if (progress.subStart === 0) {
        progress.subStart = progress.targetSubStart = progress.currentPosition;
      } else {
        // Catch-up rate is normalized to real elapsed time
        // so it animates at the same perceived speed regardless of
        // the display's actual refresh rate.
        progress.subStart = Math.min(
          progress.subStart + (elapsedMs / (1000 / 60)) * 0.1,
          progress.targetSubStart,
        );
      }

      const subPosition =
        progress.currentPosition > 0
          ? ((progress.currentPosition - progress.subStart) /
              progress.currentPosition) *
            100
          : 0;

      if (progressBarRef.current) {
        progressBarRef.current.style.width = `${progress.currentPosition}%`;
      }
      if (subProgressBarRef.current) {
        subProgressBarRef.current.style.width = `${subPosition}%`;
      }

      frameId = requestAnimationFrame(renderFrame);
    };

    frameId = requestAnimationFrame(renderFrame);
    return () => cancelAnimationFrame(frameId);
  }, []);

  // Keep the terminal scrolled to the newest line.
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [messages]);

  return (
    <>
      <div className="container_terminal" ref={terminalRef}>
        {messages.map((msg, index) => (
          <p key={index} className="terminal_text">
            {msg.warning ? '☒ ' : ''}
            {msg.text}
          </p>
        ))}
      </div>
      <div className="container_progress">
        <div className="progress_bar" ref={progressBarRef}>
          <div className="sub_progress_bar" ref={subProgressBarRef} />
        </div>
      </div>
    </>
  );
}
