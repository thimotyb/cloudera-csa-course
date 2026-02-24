-- Tumbling: finestre fisse non sovrapposte.
-- Ogni evento contribuisce a una sola finestra.
SELECT
  window_start,
  window_end,
  COUNT(*) AS buy_cnt
FROM TABLE(
  TUMBLE(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '30' SECOND)
)
WHERE behavior = 'buy'
GROUP BY window_start, window_end;
