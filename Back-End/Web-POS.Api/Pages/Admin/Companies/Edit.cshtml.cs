using Api.Admin;
using Api.Commands.CompanyCommands.Update;
using Api.Models;
using Api.Queries.CompanyQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin.Companies;

public class EditModel : PageModel
{
    private readonly IMediator _mediator;
    public EditModel(IMediator mediator) => _mediator = mediator;

    [BindProperty] public InputModel Input { get; set; } = new();

    /// Chosen file, if the admin is replacing the logo. Absent leaves the
    /// stored one alone — an edit that does not touch the field must not wipe it.
    [BindProperty] public IFormFile? Logo { get; set; }

    /// Set by the Remove checkbox. Distinct from "no file chosen", which means
    /// "keep what is there".
    [BindProperty] public bool RemoveLogo { get; set; }

    /// Whether a logo is stored, so the form can show it and offer Remove.
    public bool HasLogo { get; private set; }

    public class InputModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int CountryId { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Address { get; set; }
        public string? City { get; set; }
        public string? PostalCode { get; set; }
        public string? TaxNumber { get; set; }
    }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var c = await _mediator.Send(new GetCompanyByIdQuery(id));
        if (c == null)
        {
            TempData["Error"] = $"Company {id} not found.";
            return RedirectToPage("Index");
        }
        HasLogo = CompanyLogoFile.ContentType(c.Logo) is not null;
        Input = new InputModel
        {
            Id = c.Id,
            Name = c.Name,
            CountryId = c.CountryId,
            Email = c.Email,
            PhoneNumber = c.PhoneNumber,
            Address = c.Address,
            City = c.City,
            PostalCode = c.PostalCode,
            TaxNumber = c.TaxNumber,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        // Read before anything is written, so a rejected file leaves the rest
        // of the edit unapplied rather than half-saved.
        if (!CompanyLogoFile.TryRead(Logo, out var logoBytes, out var logoError))
        {
            TempData["Error"] = logoError;
            await ReloadLogoStateAsync();
            return Page();
        }

        try
        {
            await _mediator.Send(new UpdateCompanyCommand(new UpdateCompanyRequest
            {
                Id = Input.Id,
                Name = Input.Name,
                CountryId = Input.CountryId,
                Email = Input.Email,
                PhoneNumber = Input.PhoneNumber,
                Address = Input.Address,
                City = Input.City,
                PostalCode = Input.PostalCode,
                TaxNumber = Input.TaxNumber,
            }));
            // Replace wins over remove: a file was chosen, so the ticked
            // checkbox was almost certainly left over from before picking it.
            if (logoBytes is not null)
            {
                await _mediator.Send(new UpdateCompanyLogoCommand(
                    new UpdateCompanyLogoRequest { Id = Input.Id, Logo = logoBytes }));
            }
            else if (RemoveLogo)
            {
                await _mediator.Send(new DeleteCompanyLogoCommand(Input.Id));
            }

            TempData["Success"] = "Company updated.";
            return RedirectToPage("Details", new { id = Input.Id });
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
            await ReloadLogoStateAsync();
            return Page();
        }
    }

    /// Re-reads whether a logo is stored before re-rendering the form. Without
    /// it a failed post drops HasLogo to false and the preview and Remove box
    /// vanish, which reads as "the edit deleted my logo".
    private async Task ReloadLogoStateAsync()
    {
        try
        {
            var c = await _mediator.Send(new GetCompanyByIdQuery(Input.Id));
            HasLogo = CompanyLogoFile.ContentType(c?.Logo) is not null;
        }
        catch { HasLogo = false; }
    }
}
