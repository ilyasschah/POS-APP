using System.Net;
using System.Text.RegularExpressions;
using Api.Admin;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The company logo an admin uploads in the portal.
///
/// 🚨 The format rule is the part worth pinning. This logo is not decoration:
/// the POS prints it on every receipt and invoice through the Dart <c>pdf</c>
/// package's <c>MemoryImage</c>, which reads PNG and JPEG and nothing else. A
/// WebP or AVIF uploads without complaint, renders perfectly in the admin
/// portal — browsers handle both — and then prints as a blank space. Nobody
/// sees that until a customer is holding the paper, so it is refused at upload
/// and these tests are what keep it refused.
/// </summary>
public class CompanyLogoTests : IClassFixture<AdminPortalFactory>
{
    private readonly AdminPortalFactory _factory;

    public CompanyLogoTests(AdminPortalFactory factory) => _factory = factory;

    // Real signatures, not whole files: the check under test reads the first
    // bytes and nothing else.
    private static byte[] Png(int padTo = 64)
    {
        var bytes = new byte[padTo];
        new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }.CopyTo(bytes, 0);
        return bytes;
    }

    private static byte[] Jpeg(int padTo = 64)
    {
        var bytes = new byte[padTo];
        new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 }.CopyTo(bytes, 0);
        return bytes;
    }

    /// RIFF....WEBP — the format an admin is most likely to have to hand, and
    /// the one that would silently print nothing.
    private static byte[] WebP()
    {
        var bytes = new byte[64];
        "RIFF"u8.ToArray().CopyTo(bytes, 0);
        "WEBP"u8.ToArray().CopyTo(bytes, 8);
        return bytes;
    }

    [Fact]
    public void Png_and_jpeg_are_recognised()
    {
        Assert.Equal(CompanyLogoFile.PngContentType, CompanyLogoFile.ContentType(Png()));
        Assert.Equal(CompanyLogoFile.JpegContentType, CompanyLogoFile.ContentType(Jpeg()));
    }

    [Fact]
    public void Anything_the_till_cannot_print_is_not_recognised()
    {
        Assert.Null(CompanyLogoFile.ContentType(WebP()));
        Assert.Null(CompanyLogoFile.ContentType("<svg xmlns='...'/>"u8.ToArray()));
        Assert.Null(CompanyLogoFile.ContentType(new byte[] { 0x00, 0x01, 0x02 }));
    }

    [Fact]
    public void No_bytes_is_not_a_logo()
    {
        Assert.Null(CompanyLogoFile.ContentType(null));
        Assert.Null(CompanyLogoFile.ContentType(Array.Empty<byte>()));
    }

    [Fact]
    public void A_renamed_webp_is_still_refused()
    {
        // The whole reason the format is decided by signature. This file claims
        // to be a PNG in both its name and its content type, the two things a
        // browser supplies, and is a WebP.
        var file = new FakeFormFile(WebP(), "logo.png", CompanyLogoFile.PngContentType);

        var ok = CompanyLogoFile.TryRead(file, out var bytes, out var error);

        Assert.False(ok);
        Assert.Null(bytes);
        Assert.Contains("PNG or JPEG", error);
    }

    [Fact]
    public void A_real_png_is_read_through_unchanged()
    {
        var source = Png();
        var file = new FakeFormFile(source, "logo.png", CompanyLogoFile.PngContentType);

        var ok = CompanyLogoFile.TryRead(file, out var bytes, out var error);

        Assert.True(ok);
        Assert.Null(error);
        Assert.Equal(source, bytes);
    }

    [Fact]
    public void No_file_chosen_is_success_with_nothing_to_store()
    {
        // Not an error: the logo is optional on Create, and on Edit an empty
        // field means "keep the one already stored".
        var ok = CompanyLogoFile.TryRead(null, out var bytes, out var error);

        Assert.True(ok);
        Assert.Null(bytes);
        Assert.Null(error);
    }

    [Fact]
    public void An_oversize_file_is_refused_before_it_is_read()
    {
        var file = new FakeFormFile(Png(), "logo.png", CompanyLogoFile.PngContentType)
        {
            OverrideLength = CompanyLogoFile.MaxBytes + 1,
        };

        var ok = CompanyLogoFile.TryRead(file, out var bytes, out var error);

        Assert.False(ok);
        Assert.Null(bytes);
        Assert.Contains("limit", error);
        Assert.False(file.WasRead, "the file should be rejected on its declared "
            + "length, not copied into memory first");
    }

    [Fact]
    public async Task The_create_page_can_actually_carry_a_file()
    {
        // 🚨 A file input on a form without multipart/form-data binds to null and
        // the logo is silently dropped — the page looks right, the company is
        // created, and no logo ever arrives. Assert the encoding, not just the
        // input.
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();
        await SignInAsync(client);

        var response = await client.GetAsync("/admin/companies/create");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var html = await response.Content.ReadAsStringAsync();

        var input = Regex.Match(html, "<input[^>]*type=\"file\"[^>]*name=\"Logo\"[^>]*>");
        Assert.True(input.Success, "The create page has no Logo file input.");

        // The ENCLOSING form is the one that matters, and it is not the first on
        // the page — the layout renders a sign-out form above it.
        var openingTags = Regex.Matches(html[..input.Index], "<form[^>]*>");
        Assert.True(openingTags.Count > 0, "The Logo input is not inside a form.");
        Assert.Contains("multipart/form-data", openingTags[^1].Value);
    }

    [Fact]
    public async Task The_logo_is_not_public()
    {
        // It is served by a handler under /Admin, so it inherits that folder's
        // authorization. A tenant's branding is not anonymous-readable.
        var client = _factory.CreatePortalClient();

        var response = await client.GetAsync("/admin/companies?handler=Logo&id=1");

        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
        Assert.Contains(
            AdminPortalAuth.LoginPath,
            response.Headers.Location!.ToString(),
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task A_company_with_no_logo_serves_404_rather_than_an_empty_image()
    {
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();
        await SignInAsync(client);

        // No company owns this id, so there is certainly no logo behind it.
        var response = await client.GetAsync("/admin/companies?handler=Logo&id=-1");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private static async Task SignInAsync(HttpClient client)
    {
        var html = await (await client.GetAsync(AdminPortalAuth.LoginPath))
            .Content.ReadAsStringAsync();
        var token = Regex.Match(
            html,
            """<input name="__RequestVerificationToken" type="hidden" value="([^"]+)" />""");
        Assert.True(token.Success, "No antiforgery token on the login page.");

        var response = await client.PostAsync(AdminPortalAuth.LoginPath,
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["Input.Username"] = AdminPortalFactory.AdminUsername,
                ["Input.Password"] = AdminPortalFactory.AdminPassword,
                ["__RequestVerificationToken"] = token.Groups[1].Value,
            }));
        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
    }

    /// <summary>
    /// An <see cref="IFormFile"/> over a byte array. Only the members
    /// <see cref="CompanyLogoFile.TryRead"/> touches are implemented;
    /// <see cref="OverrideLength"/> lets a huge upload be tested without
    /// allocating one.
    /// </summary>
    private sealed class FakeFormFile : IFormFile
    {
        private readonly byte[] _content;

        public FakeFormFile(byte[] content, string fileName, string contentType)
        {
            _content = content;
            FileName = fileName;
            ContentType = contentType;
        }

        public long? OverrideLength { get; init; }
        public bool WasRead { get; private set; }

        public string ContentType { get; }
        public string ContentDisposition => $"form-data; name=\"Logo\"; filename=\"{FileName}\"";
        public IHeaderDictionary Headers => new HeaderDictionary();
        public long Length => OverrideLength ?? _content.Length;
        public string Name => "Logo";
        public string FileName { get; }

        public void CopyTo(Stream target)
        {
            WasRead = true;
            target.Write(_content, 0, _content.Length);
        }

        public Task CopyToAsync(Stream target, CancellationToken cancellationToken = default)
        {
            WasRead = true;
            return target.WriteAsync(_content, 0, _content.Length, cancellationToken);
        }

        public Stream OpenReadStream()
        {
            WasRead = true;
            return new MemoryStream(_content);
        }
    }
}
