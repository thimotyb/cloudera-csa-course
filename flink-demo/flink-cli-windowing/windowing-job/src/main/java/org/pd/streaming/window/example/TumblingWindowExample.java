package org.pd.streaming.window.example;

import java.time.LocalTime;
import java.util.HashMap;
import java.util.Map;

import org.apache.flink.api.common.functions.ReduceFunction;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.source.SourceFunction;
import org.apache.flink.streaming.api.functions.windowing.ProcessAllWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;

/**
 * Windowing tutorial migrated to Flink 1.20.1 + Java 21.
 *
 * Supported modes:
 * --mode time  -> tumbling processing-time window
 * --mode count -> count window over all stream elements
 */
public final class TumblingWindowExample {

  private TumblingWindowExample() {
  }

  public static void main(String[] args) throws Exception {
    Map<String, String> params = parseArgs(args);

    String mode = params.getOrDefault("mode", "time").trim().toLowerCase();
    int timeWindowSec = parsePositiveInt(params.get("time-window-sec"), 5, "time-window-sec");
    int countWindowSize = parsePositiveInt(params.get("count-window-size"), 4, "count-window-size");
    int sourcePeriodMs = parsePositiveInt(params.get("source-period-ms"), 1000, "source-period-ms");

    if (!"time".equals(mode) && !"count".equals(mode)) {
      throw new IllegalArgumentException("--mode must be 'time' or 'count'");
    }

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    DataStream<Integer> intStream = env.addSource(new IntegerGenerator(sourcePeriodMs)).name("integer-generator");

    if ("time".equals(mode)) {
      intStream
          .windowAll(TumblingProcessingTimeWindows.of(Time.seconds(timeWindowSec)))
          .process(new TimeWindowSumFunction())
          .print();
    } else {
      intStream
          .countWindowAll(countWindowSize)
          .reduce(new SumReduceFunction())
          .map(sum -> "count-window sum=" + sum)
          .name("count-window-output")
          .print();
    }

    env.execute("windowing-tutorial-" + mode);
  }

  private static int parsePositiveInt(String value, int defaultValue, String optionName) {
    if (value == null || value.trim().isEmpty()) {
      return defaultValue;
    }

    int parsed = Integer.parseInt(value);
    if (parsed <= 0) {
      throw new IllegalArgumentException("--" + optionName + " must be > 0");
    }
    return parsed;
  }

  private static Map<String, String> parseArgs(String[] args) {
    Map<String, String> params = new HashMap<>();
    for (int i = 0; i < args.length; i++) {
      String token = args[i];
      if (!token.startsWith("--")) {
        continue;
      }

      String key = token.substring(2);
      String value = "true";
      if (i + 1 < args.length && !args[i + 1].startsWith("--")) {
        value = args[i + 1];
        i++;
      }
      params.put(key, value);
    }
    return params;
  }

  private static final class IntegerGenerator implements SourceFunction<Integer> {
    private static final long serialVersionUID = 1L;

    private final int periodMs;
    private volatile boolean running = true;

    private IntegerGenerator(int periodMs) {
      this.periodMs = periodMs;
    }

    @Override
    public void run(SourceContext<Integer> ctx) throws Exception {
      int counter = 1;
      while (running) {
        synchronized (ctx.getCheckpointLock()) {
          ctx.collect(counter);
        }

        System.out.printf("Produced integer=%d at %s%n", counter, LocalTime.now());
        counter++;
        Thread.sleep(periodMs);
      }
    }

    @Override
    public void cancel() {
      running = false;
    }
  }

  private static final class TimeWindowSumFunction extends ProcessAllWindowFunction<Integer, String, TimeWindow> {
    private static final long serialVersionUID = 1L;

    @Override
    public void process(
        Context context,
        Iterable<Integer> input,
        Collector<String> output) {
      int sum = 0;
      int count = 0;
      for (int value : input) {
        sum += value;
        count++;
      }

      output.collect(String.format(
          "time-window [%d, %d) count=%d sum=%d",
          context.window().getStart(),
          context.window().getEnd(),
          count,
          sum));
    }
  }

  private static final class SumReduceFunction implements ReduceFunction<Integer> {
    private static final long serialVersionUID = 1L;

    @Override
    public Integer reduce(Integer value1, Integer value2) {
      return value1 + value2;
    }
  }
}
