using Api.Commands.UserCommands.Update;
using Api.Models;
using Api.Queries.UserQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin.Users;

public class EditModel : PageModel
{
    private readonly IMediator _mediator;
    public EditModel(IMediator mediator) => _mediator = mediator;

    [BindProperty] public InputModel Input { get; set; } = new();

    public class InputModel
    {
        public int CompanyId { get; set; }
        public int UserId { get; set; }
        public string? Username { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public int AccessLevel { get; set; }
        public bool IsEnabled { get; set; }
    }

    public async Task<IActionResult> OnGetAsync(int id, int userId)
    {
        var u = await _mediator.Send(new GetUserByIdQuery { Id = userId, CompanyId = id });
        if (u == null)
        {
            TempData["Error"] = $"User {userId} not found.";
            return RedirectToPage("/Admin/Companies/Details", new { id });
        }
        Input = new InputModel
        {
            CompanyId = id,
            UserId = u.Id,
            Username = u.Username,
            FirstName = u.FirstName,
            LastName = u.LastName,
            Email = u.Email,
            AccessLevel = u.AccessLevel,
            IsEnabled = u.IsEnabled,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        try
        {
            await _mediator.Send(new UpdateUserCommand(new UpdateUserRequest
            {
                Id = Input.UserId,
                Username = Input.Username,
                FirstName = Input.FirstName,
                LastName = Input.LastName,
                Email = Input.Email,
                AccessLevel = Input.AccessLevel,
                IsEnabled = Input.IsEnabled,
            }, Input.CompanyId));
            TempData["Success"] = "User updated.";
            return RedirectToPage("/Admin/Companies/Details", new { id = Input.CompanyId });
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
            return Page();
        }
    }
}
