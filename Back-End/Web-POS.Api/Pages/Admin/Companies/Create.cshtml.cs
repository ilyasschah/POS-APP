using Api.Admin;
using Api.Commands.CompanyCommands.Add;
using Api.Commands.CompanyCommands.Update;
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

    /// Optional. Applied after the company exists, through the same
    /// UpdateCompanyLogoCommand the Edit page uses — CreateCompanyRequest
    /// carries no logo and does not need to.
    [BindProperty] public IFormFile? Logo { get; set; }

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
        // The FIRST user of a brand-new company: an admin, because there is
        // nobody else to grant them anything. It read 1 — which is Cashier —
        // so every company provisioned here started with no administrator at
        // all, and the only way in was to fix the row by hand.
        public int AccessLevel { get; set; } = Api.Domain.AccessLevels.Admin;
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

        // Read the logo BEFORE anything is created. Validating it afterwards
        // would leave a company provisioned but logo-less on a bad file, and
        // the admin re-submitting the form would create a second one.
        if (!CompanyLogoFile.TryRead(Logo, out var logoBytes, out var logoError))
        {
            TempData["Error"] = logoError;
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

            if (logoBytes is not null)
            {
                // A failure here must not read as "company not created" — it
                // is, and everything else about it is fine.
                try
                {
                    await _mediator.Send(new UpdateCompanyLogoCommand(
                        new UpdateCompanyLogoRequest { Id = company.Id, Logo = logoBytes }));
                }
                catch (Exception ex)
                {
                    // The success line below already says the company exists,
                    // so this only has to report the part that did not.
                    TempData["Warning"] =
                        $"The logo did not save ({ex.Message}). Add it from Edit.";
                }
            }

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
