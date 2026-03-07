# API endpoints reference

Claude Usage Tracker reads from two independent Claude API surfaces.

## Web usage endpoint

Tracks personal claude.ai usage (session window, weekly limits, Opus usage).

```
GET https://claude.ai/api/organizations/{org_id}/usage
```

**Authentication:** `Cookie: sessionKey=<sk-ant-sid01-...>`

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `five_hour.utilization` | `Int \| Double \| String` | Session usage percentage (0–100) |
| `five_hour.resets_at` | ISO 8601 string | When the 5-hour window resets |
| `seven_day.utilization` | `Int \| Double \| String` | Weekly usage percentage |
| `seven_day.resets_at` | ISO 8601 string | When the weekly window resets |
| `seven_day_opus.utilization` | `Int \| Double \| String` | Opus-specific weekly usage |
| `seven_day_sonnet.utilization` | `Int \| Double \| String` | Sonnet-specific weekly usage |

> [!NOTE]
> The `utilization` field type varies across API versions. The app handles `Int`, `Double`, and `String` representations.

## OAuth usage endpoint

The app uses this endpoint when authenticating via CLI OAuth instead of a session key. Returns the same usage data without requiring an organisation ID.

```
GET https://api.anthropic.com/api/oauth/usage
```

**Authentication:**
```
Authorization: Bearer <access_token>
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/2.1.5
```

Returns the same fields as the web usage endpoint (`five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet`).

## Console API endpoint

Tracks API console usage (billing and credits). Requires a separate API key — not the same credential as the web session key.

```
GET https://api.anthropic.com/v1/organization/{org_id}/usage
```

**Authentication:** `x-api-key: <api_key>`

> [!CAUTION]
> This endpoint returns billing data only, not the session/weekly usage statistics shown in the popover. The app fetches it separately and displays it alongside — not instead of — web usage data.

## Organisation lookup

Before fetching usage via session key, the app resolves the organisation ID if it isn't already stored:

```
GET https://claude.ai/api/organizations
```

**Authentication:** `Cookie: sessionKey=<key>`

Returns an array of `{ uuid, name }` objects. The app selects the first organisation and stores its UUID in the active profile, reusing it on subsequent fetches to skip this round-trip.

## Rate limiting

The API returns HTTP `429` with a `Retry-After` header (integer seconds) when rate-limited. The app honours this value directly rather than using fixed backoff. See [adaptive polling](../explanations/polling-and-rate-limits.md) for details.
