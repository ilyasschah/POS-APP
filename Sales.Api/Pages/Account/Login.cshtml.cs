using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.ComponentModel.DataAnnotations;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Sales.Api.Pages.Account;

[IgnoreAntiforgeryToken] // keep it simple for testing
public class LoginModel : PageModel
{
    private readonly IHttpClientFactory _httpClientFactory;

    public LoginModel(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [BindProperty]
    public LoginInput Input { get; set; } = new();

    public string? ErrorMessage { get; set; }

    public class LoginInput
    {
        [Required] public string Username { get; set; } = "";
        [Required] public string Password { get; set; } = "";
    }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        // basic check
        if (!ModelState.IsValid)
            return Page();

        // call your API login
        var client = _httpClientFactory.CreateClient();
        client.BaseAddress = new Uri("https://localhost:7004"); // Sales.Api port
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var body = new { username = Input.Username, password = Input.Password };
        var json = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

        var response = await client.PostAsync("/api/Auth/Login", json);
        if (!response.IsSuccessStatusCode)
        {
            ErrorMessage = "Login failed. Try admin / Admin@123 for now.";
            return Page();
        }

        // success → just redirect to index.html
        return Redirect("http://localhost:63644/index.html");
    }
}
