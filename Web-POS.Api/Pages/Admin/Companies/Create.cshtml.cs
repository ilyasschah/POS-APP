using Api.Commands.CompanyCommands.Add;
using Api.Commands.UserCommands.Add;
using Api.Models;
using Api.Queries.CountryQuery.Get;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin.Companies;

public class CreateModel : PageModel
{
    private readonly IMediator _mediator;
    public CreateModel(IMediator mediator) => _mediator = mediator;

    public List<CountryDto> Countries { get; private set; } = new();

    [BindProperty] public InputModel Input { get; set; } = new();

    public class InputModel
    {
        // Company
        public string Name { get; set; } = string.Empty;
        public int CountryId { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Address { get; set; }
        public string? City { get; set; }
        public string? PostalCode { get; set; }
        public string? TaxNumber { get; set; }

        // Subscription (SaaS provisioning)
        public int SeatAllowance { get; set; } = 1;
        public int SubscriptionDays { get; set; } = 30;

        // Optional first admin user
        public bool CreateFirstUser { get; set; }
        public string? Username { get; set; }
        public string? Password { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? UserEmail { get; set; }
        public int AccessLevel { get; set; } = 1;
    }

    public async Task OnGetAsync() => await LoadCountriesAsync();

    public async Task<IActionResult> OnPostAsync()
    {
        if (string.IsNullOrWhiteSpace(Input.Name))
        {
            TempData["Error"] = "Company name is required.";
            await LoadCountriesAsync();
            return Page();
        }

        try
        {
            var company = await _mediator.Send(new AddCompanyCommand(new CreateCompanyRequest
            {
                Name = Input.Name,
                CountryId = Input.CountryId,
                Email = Input.Email,
                PhoneNumber = Input.PhoneNumber,
                Address = Input.Address,
                City = Input.City,
                PostalCode = Input.PostalCode,
                TaxNumber = Input.TaxNumber,
                SeatAllowance = Input.SeatAllowance,
                SubscriptionDays = Input.SubscriptionDays,
            }));

            if (Input.CreateFirstUser)
            {
                if (string.IsNullOrWhiteSpace(Input.Username) || string.IsNullOrWhiteSpace(Input.Password))
                {
                    TempData["Error"] =
                        $"Company '{company.Name}' created, but the first user needs a username and password — add it from the company page.";
                    return RedirectToPage("Details", new { id = company.Id });
                }

                await _mediator.Send(new AddUserCommand(new CreateUserRequest
                {
                    Username = Input.Username,
                    Password = Input.Password,
                    FirstName = Input.FirstName,
                    LastName = Input.LastName,
                    Email = Input.UserEmail,
                    AccessLevel = Input.AccessLevel,
                    IsEnabled = true,
                }, company.Id));
            }

            TempData["Success"] = $"Company '{company.Name}' created.";
            return RedirectToPage("Details", new { id = company.Id });
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Create failed: {ex.Message}";
            await LoadCountriesAsync();
            return Page();
        }
    }

    private async Task LoadCountriesAsync()
    {
        try { Countries = await _mediator.Send(new GetAllCountriesQuery()); }
        catch { Countries = new(); }
    }
}
