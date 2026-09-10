using System.Text.Json;
using System.Text.Json.Serialization;

namespace Api.Serialization;

/// <summary>
/// Writes every <see cref="DateTime"/> on the wire as UTC with an explicit
/// <c>Z</c>, and reads a zone-less one back as UTC.
///
/// <para>🚨 <b>The bug this exists to end.</b> EF materialises SQL Server
/// <c>datetime2</c> columns with <see cref="DateTimeKind.Unspecified"/>, and
/// <c>System.Text.Json</c> writes that with no zone marker at all —
/// <c>"2026-09-09T21:15:22.797"</c>. Every value in this database IS UTC (the
/// server writes <c>DateTime.UtcNow</c>), but nothing on the wire SAID so, and
/// each consumer guessed differently:</para>
/// <list type="bullet">
///   <item>The Flutter till read it as LOCAL and converted to UTC, moving a sale
///     an hour EARLIER on every terminal except the one that rang it up — two
///     tills showed the same receipt an hour apart (verified on documents 198 /
///     199, 2026-09-09).</item>
///   <item>The owner dashboard rendered it as-is, so a 22:15 sale read 21:15.</item>
/// </list>
///
/// <para>Reading is the same contract in reverse: a client that sends a naive
/// string means UTC, which is what the API already assumed — so an OLD client
/// keeps behaving exactly as it does today, while a fixed one sends <c>Z</c> and
/// is honoured as written.</para>
///
/// <para>⚠️ This is for INSTANTS. A calendar date that happens to be typed as
/// <c>DateTime</c> (an expiry date, a report's day filter) has no zone and must
/// not be shifted by one; those travel as date-only strings, and the client
/// deliberately does not UTC-convert them either.</para>
/// </summary>
public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(
        ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetDateTime();

        return value.Kind switch
        {
            // No zone on the wire: the caller means UTC. Stamping the Kind is
            // what stops it being re-interpreted as server-local further down.
            DateTimeKind.Unspecified => DateTime.SpecifyKind(value, DateTimeKind.Utc),
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => value,
        };
    }

    public override void Write(
        Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        var utc = value.Kind switch
        {
            // Straight from the database. It is already UTC — it just never said so.
            DateTimeKind.Unspecified => DateTime.SpecifyKind(value, DateTimeKind.Utc),
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => value,
        };

        // "O" on a UTC DateTime is ISO-8601 with the Z: 2026-09-09T21:15:22.7970000Z
        writer.WriteStringValue(utc.ToString("O", System.Globalization.CultureInfo.InvariantCulture));
    }
}

/// <summary>
/// The nullable twin. <c>JsonConverter&lt;DateTime&gt;</c> is not consulted for
/// <c>DateTime?</c> properties, and most timestamps on these DTOs are nullable —
/// without this, half the payload would keep its old zone-less shape.
/// </summary>
public sealed class UtcNullableDateTimeConverter : JsonConverter<DateTime?>
{
    private static readonly UtcDateTimeConverter Inner = new();

    public override DateTime? Read(
        ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        => reader.TokenType == JsonTokenType.Null
            ? null
            : Inner.Read(ref reader, typeof(DateTime), options);

    public override void Write(
        Utf8JsonWriter writer, DateTime? value, JsonSerializerOptions options)
    {
        if (value is null) writer.WriteNullValue();
        else Inner.Write(writer, value.Value, options);
    }
}
