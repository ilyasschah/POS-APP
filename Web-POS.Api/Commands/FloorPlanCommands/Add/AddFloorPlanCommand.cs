using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Services;
using Api.Models;

namespace Api.Commands.FloorPlanCommands.Add
{
    public class AddFloorPlanCommand : IRequest<FloorPlanDto>
    {
        public CreateFloorPlanRequest Request { get; set; }

        public class AddFloorPlanCommandHandler : IRequestHandler<AddFloorPlanCommand, FloorPlanDto>
        {
            private readonly FloorPlanService _service;

            public AddFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<FloorPlanDto> Handle(AddFloorPlanCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperFloorPlan.MapToFloorPlanDto(newEntity);
            }
        }

        public class AddFloorPlanCommandValidator : AbstractValidator<AddFloorPlanCommand>
        {
            public AddFloorPlanCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}