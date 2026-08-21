using System.Net;
using System.Text.RegularExpressions;
using Api.Admin;
using Xunit;

namespace Api.Tests;

/// <summary>
/// End-to-end over the real pipeline. These are the tests that would have caught
/// the two ways this change locks you out of your own portal: a policy that does
/// not name the cookie scheme (so a signed-in operator is challenged forever), and
/// a login page left inside the folder's authorize convention (so the login form
/// demands a login).
/// </summary>
public class AdminPortalAuthenticationTests : IClassFixture<AdminPortalFactory>
{
    private readonly AdminPortalFactory _factory;

    public AdminPortalAuthenticationTests(AdminPortalFactory factory) => _factory = factory;

    [Fact]
    public async Task Signed_out_visitor_is_redirected_to_the_login_page()
    {
        var client = _factory.CreatePortalClient();

        var response = await client.GetAsync("/admin/companies");

        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
        Assert.Contains(
            AdminPortalAuth.LoginPath,
            response.Headers.Location!.ToString(),
            StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("/admin")]
    [InlineData("/admin/")]
    [InlineData("/")]
    public async Task The_obvious_entry_urls_lead_into_the_portal(string path)
    {
        var client = _factory.CreatePortalClient();

        var response = await client.GetAsync(path);

        // Specifically NOT 401. "/admin" matches no page, so without an explicit
        // redirect it reaches the global JWT fallback policy and the bearer handler
        // answers with a bare 401 — the browser shows "This page isn't working"
        // on the address every operator types first.
        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
        Assert.StartsWith("/admin", response.Headers.Location!.ToString());
    }

    [Fact]
    public async Task The_login_page_itself_is_reachable_while_signed_out()
    {
        var client = _factory.CreatePortalClient();

        var response = await client.GetAsync(AdminPortalAuth.LoginPath);

        // A 302 here means the login page ended up behind the login — the portal is
        // then unreachable from any browser that has never signed in, i.e. all of them.
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("Sign in", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task The_retired_shared_secret_no_longer_grants_access()
    {
        var client = _factory.CreatePortalClient();

        // Whatever AdminPortal:AccessKey used to be, ?key= is now just an ignored
        // query parameter. Any value must land on the login page like any other
        // anonymous request.
        foreach (var key in new[] { "", "wrong", "the-real-old-key-if-you-had-it" })
        {
            var response = await client.GetAsync($"/admin/companies?key={key}");

            Assert.Equal(HttpStatusCode.Found, response.StatusCode);
            Assert.Contains(
                AdminPortalAuth.LoginPath,
                response.Headers.Location!.ToString(),
                StringComparison.OrdinalIgnoreCase);
        }
    }

    [Theory]
    [InlineData("/admin/companies")]   // the 302 challenge
    [InlineData(AdminPortalAuth.LoginPath)]  // the login page body
    public async Task Security_headers_survive_on_every_admin_response(string path)
    {
        var client = _factory.CreatePortalClient();

        var response = await client.GetAsync(path);
        var headers = response.Headers;

        // The challenge case is the one that regresses: the authorization middleware
        // short-circuits it, so a header middleware registered after UseAuthorization
        // never runs for it.
        Assert.Equal("nosniff", string.Join("", headers.GetValues("X-Content-Type-Options")));
        Assert.Equal("DENY", string.Join("", headers.GetValues("X-Frame-Options")));
        Assert.Equal("no-referrer", string.Join("", headers.GetValues("Referrer-Policy")));
        Assert.Contains("no-store", string.Join("", headers.GetValues("Cache-Control")));
    }

    [Fact]
    public async Task Bad_credentials_are_rejected_with_one_message_for_every_reason()
    {
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();

        var wrongPassword = await SignInAsync(client, AdminPortalFactory.AdminUsername, "not-the-password");
        var unknownUser = await SignInAsync(client, "no-such-operator", AdminPortalFactory.AdminPassword);

        // 200 = the form redisplayed with an error. A 302 would mean it let them in.
        Assert.Equal(HttpStatusCode.OK, wrongPassword.StatusCode);
        Assert.Equal(HttpStatusCode.OK, unknownUser.StatusCode);

        var wrongPasswordBody = await wrongPassword.Content.ReadAsStringAsync();
        var unknownUserBody = await unknownUser.Content.ReadAsStringAsync();

        Assert.Contains("Incorrect username or password", wrongPasswordBody);

        // Byte-identical error text: anything that differs between the two is an
        // oracle telling an attacker which usernames are real.
        Assert.Equal(ErrorText(wrongPasswordBody), ErrorText(unknownUserBody));
    }

    [Fact]
    public async Task Sign_in_reaches_the_companies_list_and_sign_out_takes_it_away_again()
    {
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();

        var signIn = await SignInAsync(
            client, AdminPortalFactory.AdminUsername, AdminPortalFactory.AdminPassword);
        Assert.Equal(HttpStatusCode.Found, signIn.StatusCode);

        var companies = await client.GetAsync("/admin/companies");
        Assert.Equal(HttpStatusCode.OK, companies.StatusCode);

        var signOut = await PostAsync(client, AdminPortalAuth.LogoutPath, new Dictionary<string, string>(),
            await AntiforgeryTokenAsync(client, "/admin/companies"));
        Assert.Equal(HttpStatusCode.Found, signOut.StatusCode);

        // The cookie the browser still holds must no longer open anything.
        var afterSignOut = await client.GetAsync("/admin/companies");
        Assert.Equal(HttpStatusCode.Found, afterSignOut.StatusCode);
        Assert.Contains(
            AdminPortalAuth.LoginPath,
            afterSignOut.Headers.Location!.ToString(),
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task The_shell_shows_account_controls_only_once_signed_in()
    {
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();

        // Signed out: the login page must not offer navigation that would only
        // bounce straight back to it.
        var loginPage = await (await client.GetAsync(AdminPortalAuth.LoginPath)).Content.ReadAsStringAsync();
        Assert.DoesNotContain("Sign out", loginPage);
        Assert.DoesNotContain("New Company", loginPage);

        await SignInAsync(client, AdminPortalFactory.AdminUsername, AdminPortalFactory.AdminPassword);
        var companies = await (await client.GetAsync("/admin/companies")).Content.ReadAsStringAsync();

        // Signed in: an operator with no way to sign out cannot end their session,
        // which makes the logout requirement unreachable from the UI.
        Assert.Contains("Sign out", companies);
        Assert.Contains("Administrator", companies);
    }

    [Fact]
    public async Task An_account_on_the_default_password_is_warned_on_every_page()
    {
        await _factory.SeedAdminAsync();
        await _factory.SetMustChangePasswordAsync(true);

        var client = _factory.CreatePortalClient();
        await SignInAsync(client, AdminPortalFactory.AdminUsername, AdminPortalFactory.AdminPassword);

        var companies = await client.GetAsync("/admin/companies");

        // Warned, but NOT blocked — the operator still reaches the portal. A forced
        // redirect here would lock them out of every other repair they might need.
        Assert.Equal(HttpStatusCode.OK, companies.StatusCode);
        Assert.Contains("still uses the default password", await companies.Content.ReadAsStringAsync());

        await _factory.SetMustChangePasswordAsync(false);
    }

    [Fact]
    public async Task An_unreachable_master_database_does_not_render_as_a_bad_password()
    {
        // Its own host, never seeded — so the AdminUser table does not exist and
        // every query throws, exactly as it would against an unprovisioned or
        // unreachable Master DB. No shared state to restore.
        using var broken = new AdminPortalFactory();
        var client = broken.CreatePortalClient();

        var response = await SignInAsync(
            client, AdminPortalFactory.AdminUsername, AdminPortalFactory.AdminPassword);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();

        // The whole point: an operator with a perfectly good password must not be
        // told their password is wrong.
        Assert.Contains("admin database is unreachable", body);
        Assert.DoesNotContain("Incorrect username or password", body);
    }

    [Fact]
    public async Task Sign_in_does_not_follow_an_off_site_return_url()
    {
        await _factory.SeedAdminAsync();
        var client = _factory.CreatePortalClient();

        var response = await PostAsync(client, AdminPortalAuth.LoginPath,
            new Dictionary<string, string>
            {
                ["Input.Username"] = AdminPortalFactory.AdminUsername,
                ["Input.Password"] = AdminPortalFactory.AdminPassword,
                ["returnUrl"] = "https://evil.example.com/harvest",
            },
            await AntiforgeryTokenAsync(client, AdminPortalAuth.LoginPath));

        Assert.Equal(HttpStatusCode.Found, response.StatusCode);
        var location = response.Headers.Location!.ToString();
        Assert.DoesNotContain("evil.example.com", location);
        Assert.StartsWith("/", location);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static async Task<HttpResponseMessage> SignInAsync(
        HttpClient client, string username, string password)
    {
        var token = await AntiforgeryTokenAsync(client, AdminPortalAuth.LoginPath);
        return await PostAsync(client, AdminPortalAuth.LoginPath,
            new Dictionary<string, string>
            {
                ["Input.Username"] = username,
                ["Input.Password"] = password,
            },
            token);
    }

    /// <summary>
    /// Razor Pages validates an antiforgery token on every POST, so a test that
    /// skips it gets a 400 and proves nothing about the credentials.
    /// </summary>
    private static async Task<string> AntiforgeryTokenAsync(HttpClient client, string path)
    {
        var html = await (await client.GetAsync(path)).Content.ReadAsStringAsync();
        var match = Regex.Match(
            html,
            """<input name="__RequestVerificationToken" type="hidden" value="([^"]+)" />""");
        Assert.True(match.Success, $"No antiforgery token found on {path}.");
        return match.Groups[1].Value;
    }

    private static Task<HttpResponseMessage> PostAsync(
        HttpClient client, string path, Dictionary<string, string> fields, string antiforgeryToken)
    {
        fields["__RequestVerificationToken"] = antiforgeryToken;
        return client.PostAsync(path, new FormUrlEncodedContent(fields));
    }

    /// <summary>Pulls the rendered error banner out of the login page.</summary>
    private static string ErrorText(string html)
    {
        var match = Regex.Match(html, @"class=""alert alert-danger"" role=""alert"">([\s\S]*?)</div>");
        Assert.True(match.Success, "The login page rendered no error banner.");
        return match.Groups[1].Value.Trim();
    }
}
