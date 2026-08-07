using Api.Commands.CompanyCommands.Delete;
using Api.Models;
using Api.Queries.CompanyQuery;
using Api.Services;
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
        catch (CompanyPartiallyDeletedException ex)
        {
            // The company's own data IS gone — only the Master-DB licensing
            // tenant survived. Reporting a plain "Delete failed" would be a lie
            // in the other direction, and reporting success (what this page used
            // to do, because the failure was swallowed as a LogWarning) is why
            // "I deleted a company and it didn't delete all its data" went
            // unnoticed. Say exactly what is left.
            TempData["Warning"] = ex.Message;
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Delete failed: {ex.Message}";
        }
        return RedirectToPage();
    }
}
