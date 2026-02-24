-- Cumulative: finestre progressive dallo stesso start.
-- Con step=10s e max=1m ottieni parziali crescenti.
SELECT
  window_start,
  window_end,
  COUNT(*) AS buy_cnt
FROM TABLE(
  CUMULATE(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '10' SECOND, INTERVAL '1' MINUTE)
)
WHERE behavior = 'buy'
GROUP BY window_start, window_end;
