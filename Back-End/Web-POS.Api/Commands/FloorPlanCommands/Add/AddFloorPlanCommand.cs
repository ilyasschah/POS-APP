using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Commands.FloorPlanCommands.Add
{
    public class AddFloorPlanCommand : IRequest<FloorPlanDto>
    {
        public required CreateFloorPlanRequest Request { get; set; }
        public int CompanyId { get; set; }

        public class AddFloorPlanCommandHandler : IRequestHandler<AddFloorPlanCommand, FloorPlanDto>
        {
            private readonly FloorPlanService _service;

            public AddFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<FloorPlanDto> Handle(AddFloorPlanCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }
    }

    public class AddFloorPlanCommandValidator : AbstractValidator<AddFloorPlanCommand>
    {
        public AddFloorPlanCommandValidator()
        {
            RuleFor(x => x.CompanyId)
                .GreaterThan(0).WithMessage("CompanyId is required and must be greater than 0.");

            RuleFor(x => x.Request.Name)
                .NotEmpty().WithMessage("Name is required.");
        }
    }
}