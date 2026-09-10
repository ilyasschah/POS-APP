using System.Text.Json;
using Api.Serialization;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Every timestamp this API writes must say which zone it is in.
///
/// <para>What went wrong without it, measured on two real tills on 2026-09-09:
/// EF materialises SQL Server <c>datetime2</c> columns as
/// <see cref="DateTimeKind.Unspecified"/>, and <c>System.Text.Json</c> writes
/// that with no marker — <c>"2026-09-09T21:15:22.797"</c>. Every value in the
/// database IS UTC; nothing on the wire said so, and each consumer guessed:</para>
/// <list type="bullet">
///   <item>The Flutter till read it as LOCAL, so a sale rung up at 22:15 in
///     Casablanca was filed on every OTHER terminal as 21:15 — the same receipt
///     showing two different times on two screens in the same shop.</item>
///   <item>The owner dashboard printed it raw, an hour off the shop's clock.</item>
/// </list>
///
/// <para>These pin the contract in both directions, because the API is both ends
/// of it: what it writes must be unambiguous, and what it reads from a client
/// that is not yet fixed must keep meaning exactly what it used to.</para>
/// </summary>
public class UtcDateTimeSerializationTests
{
    private static readonly JsonSerializerOptions Options = BuildOptions();

    private static JsonSerializerOptions BuildOptions()
    {
        var options = new JsonSerializerOptions();
        options.Converters.Add(new UtcDateTimeConverter());
        options.Converters.Add(new UtcNullableDateTimeConverter());
        return options;
    }

    private sealed class Payload
    {
        public DateTime When { get; set; }
        public DateTime? Maybe { get; set; }
    }

    // ── Writing ──────────────────────────────────────────────────────────────

    [Fact]
    public void A_database_timestamp_is_written_as_UTC_with_a_Z()
    {
        // Exactly what EF hands back from datetime2: no Kind at all.
        var fromDatabase = new DateTime(2026, 9, 9, 21, 15, 22, 797, DateTimeKind.Unspecified);

        var json = JsonSerializer.Serialize(new Payload { When = fromDatabase }, Options);

        Assert.Contains("2026-09-09T21:15:22.7970000Z", json);
    }

    [Fact]
    public void The_clock_reading_is_not_shifted_only_labelled()
    {
        // The one thing that must NOT happen: "fixing" the marker by moving the
        // number. The database value already IS the UTC instant.
        var fromDatabase = new DateTime(2026, 9, 9, 21, 15, 22, DateTimeKind.Unspecified);

        var json = JsonSerializer.Serialize(new Payload { When = fromDatabase }, Options);

        Assert.Contains("T21:15:22", json);
        Assert.DoesNotContain("T22:15:22", json);
        Assert.DoesNotContain("T20:15:22", json);
    }

    [Fact]
    public void A_UTC_timestamp_is_written_unchanged()
    {
        var utc = new DateTime(2026, 9, 9, 21, 15, 22, DateTimeKind.Utc);

        var json = JsonSerializer.Serialize(new Payload { When = utc }, Options);

        Assert.Contains("2026-09-09T21:15:22.0000000Z", json);
    }

    [Fact]
    public void A_nullable_timestamp_gets_the_same_treatment()
    {
        // DateTime? does NOT go through JsonConverter<DateTime>, and most
        // timestamps on these DTOs are nullable — half the payload would have
        // kept its old shape without the second converter.
        var payload = new Payload
        {
            Maybe = new DateTime(2026, 9, 9, 21, 15, 22, DateTimeKind.Unspecified),
        };

        var json = JsonSerializer.Serialize(payload, Options);

        Assert.Contains("2026-09-09T21:15:22.0000000Z", json);
    }

    [Fact]
    public void A_null_timestamp_stays_null()
    {
        var json = JsonSerializer.Serialize(new Payload { Maybe = null }, Options);

        Assert.Contains("\"Maybe\":null", json);
    }

    // ── Reading ──────────────────────────────────────────────────────────────

    [Fact]
    public void A_client_that_sends_no_zone_still_means_UTC()
    {
        // Backwards compatibility, and it matters: a till in the field that has
        // not taken the new build sends exactly this. Reading it as UTC is what
        // the API already did by accident — so nothing changes for that client.
        var payload = JsonSerializer.Deserialize<Payload>(
            """{"When":"2026-09-09T21:26:37"}""", Options)!;

        Assert.Equal(DateTimeKind.Utc, payload.When.Kind);
        Assert.Equal(new DateTime(2026, 9, 9, 21, 26, 37, DateTimeKind.Utc), payload.When);
    }

    [Fact]
    public void A_client_that_sends_a_Z_is_honoured()
    {
        var payload = JsonSerializer.Deserialize<Payload>(
            """{"When":"2026-09-09T21:26:37Z"}""", Options)!;

        Assert.Equal(new DateTime(2026, 9, 9, 21, 26, 37, DateTimeKind.Utc), payload.When);
    }

    [Fact]
    public void A_client_that_sends_an_offset_is_converted()
    {
        // The fixed till sends UTC, but an offset is legal ISO-8601 and must not
        // be taken at face value: 22:26 at +01:00 is 21:26 UTC.
        var payload = JsonSerializer.Deserialize<Payload>(
            """{"When":"2026-09-09T22:26:37+01:00"}""", Options)!;

        Assert.Equal(DateTimeKind.Utc, payload.When.Kind);
        Assert.Equal(new DateTime(2026, 9, 9, 21, 26, 37, DateTimeKind.Utc), payload.When);
    }

    [Fact]
    public void The_round_trip_does_not_move_an_instant()
    {
        // The property the whole fix rests on: a session opened at a moment is
        // read back at that same moment, whatever zone anything is in.
        var original = new DateTime(2026, 9, 9, 21, 26, 37, 123, DateTimeKind.Utc);

        var json = JsonSerializer.Serialize(new Payload { When = original }, Options);
        var returned = JsonSerializer.Deserialize<Payload>(json, Options)!.When;

        Assert.Equal(original, returned);
        Assert.Equal(DateTimeKind.Utc, returned.Kind);
    }
}
