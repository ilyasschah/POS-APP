using Api.Commands.CompanyCommands.Delete;
using Api.Models;
using Api.Queries.CompanyQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin.Companies;

public class IndexModel : PageModel
{
    private readonly IMediator _mediator;
    public IndexModel(IMediator mediator) => _mediator = mediator;

    public List<CompanyDto> Companies { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Companies = await _mediator.Send(new GetAllCompaniesQuery());
    }

    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        try
        {
            await _mediator.Send(new DeleteCompanyCommand(id));
            TempData["Success"] = "Company and all its data were deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Delete failed: {ex.Message}";
        }
        return RedirectToPage();
    }
}
