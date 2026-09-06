using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ApplicationPropertyCommands.Update
{
    public class UpdateApplicationPropertyCommand : IRequest<bool>
    {
        public UpdateApplicationPropertyRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateApplicationPropertyCommand(UpdateApplicationPropertyRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateApplicationPropertyCommandHandler : IRequestHandler<UpdateApplicationPropertyCommand, bool>
        {
            private readonly ApplicationPropertyService _service;

            public UpdateApplicationPropertyCommandHandler(ApplicationPropertyService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdateApplicationPropertyCommand command, CancellationToken cancellationToken)
            {
                return await _service.UpdateValueAsync(command.Request, command.CompanyId);
            }
        }

        public class UpdateApplicationPropertyCommandValidator : AbstractValidator<UpdateApplicationPropertyCommand>
        {
            public UpdateApplicationPropertyCommandValidator()
            {
                RuleFor(cmd => cmd.Request.Id).GreaterThan(0).WithMessage("Property ID must be valid.");
                // NotNull only — see AddApplicationPropertyCommandValidator. Clearing
                // a setting to "" is a normal edit (it is how four of the seeded
                // defaults ship), so NotEmpty() here would block the Settings screen
                // from ever emptying a field once validation is enforced.
                RuleFor(cmd => cmd.Request.NewValue).NotNull().WithMessage("New value must not be null.");
                RuleFor(cmd => cmd.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}