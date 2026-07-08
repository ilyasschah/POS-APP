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
            TempData["Success"] = "Company updated.";
            return RedirectToPage("Details", new { id = Input.Id });
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
            return Page();
        }
    }
}
