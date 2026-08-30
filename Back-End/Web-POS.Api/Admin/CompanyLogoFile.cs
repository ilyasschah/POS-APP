namespace Api.Admin;

/// <summary>
/// Reads and validates the logo an admin uploads for a company, and works out
/// the content type to serve it back with.
///
/// 🚨 PNG and JPEG only, and that is not a matter of taste. The POS prints this
/// logo through the Dart <c>pdf</c> package's <c>MemoryImage</c>, which decodes
/// those two formats and nothing else. A WebP, SVG or AVIF uploads happily and
/// renders correctly in this portal — every browser handles them — and then
/// prints as NOTHING on every receipt and invoice. That is a failure nobody
/// sees until a customer is handed the paper, so it is refused at the door.
///
/// The format is decided by the file's own magic bytes, never by its extension
/// or the browser-supplied content type: a <c>logo.webp</c> renamed to
/// <c>logo.png</c> announces itself as a PNG and would otherwise sail through.
/// </summary>
public static class CompanyLogoFile
{
    /// Comfortably more than a print-quality logo needs, small enough that the
    /// bytes stay cheap to ship inside every company payload the POS syncs.
    public const int MaxBytes = 2 * 1024 * 1024;

    /// For the file input's `accept`. A hint to the picker only — the check
    /// that matters is the signature test below.
    public const string Accept = "image/png,image/jpeg";

    public const string PngContentType = "image/png";
    public const string JpegContentType = "image/jpeg";

    private static readonly byte[] PngSignature =
        { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

    private static readonly byte[] JpegSignature = { 0xFF, 0xD8, 0xFF };

    /// <summary>
    /// The content type for stored logo bytes, or null when they are absent or
    /// not a format the POS can print.
    /// </summary>
    public static string? ContentType(byte[]? bytes)
    {
        if (bytes is null || bytes.Length == 0) return null;
        if (StartsWith(bytes, PngSignature)) return PngContentType;
        if (StartsWith(bytes, JpegSignature)) return JpegContentType;
        return null;
    }

    /// <summary>
    /// Reads an uploaded logo. Returns false with a message an admin can act on
    /// when the file is unusable; returns true with a null <paramref name="bytes"/>
    /// when no file was chosen, which is not an error — the logo is optional.
    /// </summary>
    public static bool TryRead(IFormFile? file, out byte[]? bytes, out string? error)
    {
        bytes = null;
        error = null;

        if (file is null || file.Length == 0) return true;

        if (file.Length > MaxBytes)
        {
            error = $"Logo is {file.Length / 1024d / 1024d:0.0} MB — the limit is "
                  + $"{MaxBytes / 1024 / 1024} MB.";
            return false;
        }

        byte[] read;
        using (var buffer = new MemoryStream())
        {
            file.CopyTo(buffer);
            read = buffer.ToArray();
        }

        if (ContentType(read) is null)
        {
            error = "Logo must be a PNG or JPEG. Other formats display here but "
                  + "print as a blank space on receipts and invoices.";
            return false;
        }

        bytes = read;
        return true;
    }

    private static bool StartsWith(byte[] bytes, byte[] signature)
    {
        if (bytes.Length < signature.Length) return false;
        for (var i = 0; i < signature.Length; i++)
        {
            if (bytes[i] != signature[i]) return false;
        }
        return true;
    }
}
