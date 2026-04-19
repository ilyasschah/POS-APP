using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Commands.FloorPlanCommands.Update
{
    public class UpdateFloorPlanCommand : IRequest<bool>
    {
        public required UpdateFloorPlanRequest Request { get; set; }
        public int CompanyId { get; set; }

        public class UpdateFloorPlanCommandHandler : IRequestHandler<UpdateFloorPlanCommand, bool>
        {
            private readonly FloorPlanService _service;

            public UpdateFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdateFloorPlanCommand command, CancellationToken cancellationToken)
            {
                return await _service.UpdateAsync(command.Request, command.CompanyId);
            }
        }
    }

    public class UpdateFloorPlanCommandValidator : AbstractValidator<UpdateFloorPlanCommand>
    {
        public UpdateFloorPlanCommandValidator()
        {
            RuleFor(x => x.CompanyId)
                .GreaterThan(0).WithMessage("CompanyId is required and must be greater than 0.");

            RuleFor(x => x.Request.Id)
                .GreaterThan(0).WithMessage("Id is required and must be greater than 0.");

            RuleFor(x => x.Request.Name)
                .NotEmpty().WithMessage("Name is required.");

            RuleFor(x => x.Request.Color)
                .NotEmpty().WithMessage("Color is required.");
        }
    }
}